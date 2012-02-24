#!/usr/bin/env ruby
require 'rubygems'
require 'eventmachine'
require 'rufus-scheduler'
require 'json'

callpath = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << callpath
$LOAD_PATH << "#{callpath}/lib"

require 'mc-debugger-tk'

class Hash
  def symbolize_keys
    inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end

  def symbolize_keys!
     self.replace(self.symbolize_keys)
  end
end

module Runner
  @@usock= '/tmp/sched.sock'
  @@jobpath = '/tmp/sched'

  module_function

  def lock_n_write(filename, msg)
    (f= File.open(filename, 'w')).flock(File::LOCK_EX)
    f.write(msg)
    f.flock(File::LOCK_UN)
    f.close
  end

  def load_scheduler
    # Yes, I'm using PlainScheduler instead of EMScheduler
    # This is on purpose
    @@scheduler = Rufus::Scheduler::PlainScheduler.start_new(
                           :thread_name => 'Rufus Scheduler')        
    def @@scheduler.handle_exception(job, exception)
      err = "Caught exception '#{exception}'"
      Runner.lock_n_write("#{@@jobpath}/#{job.tags}.exception", err)
    end
  end

  def start_msg_handler
    EventMachine::start_unix_domain_server(@@usock, MsgHandler)
  end

  def clean_sock(sock)
    File.umask 0000
    File.unlink(sock) if File.exists?(sock)
  end

  def create_dir(dir)
    begin
      Dir::mkdir(dir)
    rescue Errno::EEXIST
    end
  end

  def run 
    clean_sock(@@usock)
    create_dir(@@jobpath)
    EventMachine::run do
      start_msg_handler
      load_scheduler
    end    
  end

  def log_err(jobid, errmsg)
    lock_n_write("#{@@jobpath}/#{jobid}.err", errmsg )
    puts "#{jobid} : ERR : #{errmsg}"
  end

  def log_out(jobid, result)
    lock_n_write("#{@@jobpath}/#{jobid}.out", result.to_json )
  end

  def log_desc(jobid, jobdesc)
    lock_n_write("#{@@jobpath}/#{jobid}.desc", jobdesc.to_json )
  end

  def addjob(j)
    puts j['job_id']
    @@scheduler.send(j['job_type'], j['job_arg'], :tags => j['job_id']) do
      configfile = "/etc/mcollective/server.cfg"
      McDebugger.features = {:trace => false}
      begin
        McDebugger.setup(configfile, :info)
      rescue RuntimeError
        # Already loaded ?
      end
      j['action_args'].symbolize_keys!
      #res = McDebugger.call(j['agent_name'], j['action_name'], j['action_args'])
      callpath = File.expand_path(File.dirname(__FILE__))
      system("ruby #{callpath}/mc-local-jobdesc.rb #{@@jobpath}/#{j['job_id']}.desc")
    end
  end

  def status(jobid)
    @@scheduler.running_jobs.each do |job|
      return 'running' if job.tags[0] == jobid
    end
    @@scheduler.all_jobs.each do |job| 
      return 'scheduled' if job[1].tags[0] == jobid
    end
    return 'exception' if File::exists?( "#{@@jobpath}/#{jobid}.exception" )
    return 'error'     if File::exists?( "#{@@jobpath}/#{jobid}.err" )
    return 'finished'  if File::exists?( "#{@@jobpath}/#{jobid}.out" )
    return 'lost in space'
  end
end

module MsgHandler
  def receive_data(msg)
    msg = parsemsg(msg)
    job = validate_msg(msg)
    case job['reqtype']
      when 'add'
      runner.log_desc(job['job_id'], job)
      runner.addjob(job)
      when 'status'
      status=runner.status(job['job_id'])
      send_data(status)
    end
    close_connection_after_writing
  end

  def unbind
  end

  def runner
    Runner
  end

  module_function

  def parsemsg(msg)
    begin 
      JSON.parse(msg)
    rescue JSON::ParserError
      Hash.new 
    end
  end

  def validate_msg(j)
    # That's a start, let's say...
    basicfields = [ 'reqtype', 'job_id' ]
    basicfields.each { |key| return Hash.new unless j[key] }

    addfields = ['agent_name', 'action_name', 'job_type', 'job_arg' ]
    if j['reqtype'] == 'add'             
      addfields.each { |key| return Hash.new unless j[key] }
      return Hash.new unless j['job_type'] =~ /^(at|cron|every|in|now)$/
      j['action_args'] ||= {}
      j['job_type'], j['job_arg'] = 'in', '0s' if j['job_type'] == 'now'
    end

    j
  end

end

