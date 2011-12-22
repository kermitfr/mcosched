#!/usr/bin/ruby
require 'rubygems'
require 'eventmachine'
require 'rufus-scheduler'
require 'json'

callpath = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << callpath
$LOAD_PATH << "#{callpath}/lib"

module Runner
  @@usock= '/tmp/sched.sock'
  @@jobpath = '/tmp/sched'

  def load_scheduler
    # Yes, I'm using PlainScheduler instead of EMScheduler
    # This is on purpose
    @@scheduler = Rufus::Scheduler::PlainScheduler.start_new(
                           :thread_name => 'Rufus Scheduler')        
    def @@scheduler.handle_exception(job, exception)
      err = "Caught exception '#{exception}'"
      File.open("#{@@jobpath}/#{job.tags}.exception", 'w') do |f|
        f.write(err)
      end
    end
  end
  module_function :load_scheduler

  def start_msg_handler
    EventMachine::start_unix_domain_server(@@usock, MsgHandler)
  end
  module_function :start_msg_handler

  def clean_sock(sock)
    File.umask 0000
    File.unlink(sock) if File.exists?(sock)
  end
  module_function :clean_sock

  def create_dir(dir)
    begin
      Dir::mkdir(dir)
    rescue Errno::EEXIST
    end
  end
  module_function :create_dir

  def run 
    clean_sock(@@usock)
    create_dir(@@jobpath)
    EventMachine::run do
      start_msg_handler
      load_scheduler
    end    
  end
  module_function :run

  def log_err(jobid, errmsg)
    File.open("#{@@jobpath}/#{jobid}.err", 'w') do |f|
      f.write(errmsg)
    end  
    puts "#{jobid} : ERR : #{errmsg}"
  end
  module_function :log_err

  def log_out(jobid, result)
    File.open("#{@@jobpath}/#{jobid}.out", 'w') do |f| 
      f.write(result.to_json)
    end 
  end
  module_function :log_out

  def log_desc(jobid, jobdesc)
    File.open("#{@@jobpath}/#{jobid}.desc", 'w') do |f| 
      f.write(jobdesc.to_json)
    end 
  end
  module_function :log_desc

  def require_module(modfile)
    begin
      require modfile 
    rescue LoadError
      puts "LoadError on #{modfile}"
    end
  end
  module_function :require_module

  def call_method(required_module, method_name, method_args, job_id)
    if required_module.respond_to?(method_name) then
      required_method = required_module.method(method_name)
      result = required_method.call(method_args)
      log_out(job_id, result)
    else
      errmsg = "Invalid method '#{method_name}' for module '#{module_name}'"
      log_err(job_id, errmsg)
    end
  end
  module_function :call_method
 
  def schedule(j)
    @@scheduler.send(j['job_type'], j['job_arg'], :tags => j['job_id']) do
      if Object.const_defined?(j['module_name'])
        req_module = Kernel.const_get(j['module_name'])
        call_method(req_module, j['method_name'], j['method_args'], j['job_id'])
      else
        errmsg = "Invalid module '#{j['module_name']}'"
        log_err(j['job_id'], errmsg)
      end
    end
  end
  module_function :schedule

  def addjob(job)
    require_module(job['module_file'])
    schedule(job)
  end
  module_function :addjob

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
  module_function :status
end

module MsgHandler
  def parsemsg(msg)
    begin 
      JSON.parse(msg)
    rescue JSON::ParserError
      Hash.new 
    end
  end
  module_function :parsemsg

  def validate_msg(j)
    # That's a start, let's say...
    basicfields = [ 'reqtype', 'job_id' ]
    basicfields.each { |key| return Hash.new unless j[key] }

    addfields = ['module_name', 'method_name', 'method_args',
                 'job_type', 'job_arg' ]
    if j['reqtype'] == 'add'             
      addfields.each { |key| return Hash.new unless j[key] }
      return Hash.new unless j['job_type'] =~ /^(at|cron|every|in|now)$/
      return Hash.new unless j['module_name'] =~ /^[A-Z]/
      j['job_type'], j['job_arg'] = 'in', '0s' if j['job_type'] == 'now'
    end

    j
  end
  module_function :validate_msg

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
end



