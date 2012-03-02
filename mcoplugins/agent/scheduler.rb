require 'json'
require 'socket'

#require "eventmachine"
#MCollective::Util.loadclass("MCollective::Util::SchedHandler")

module MCollective
    module Agent 
        class Scheduler<RPC::Agent
            metadata :name        => "Part of a POC for a mco scheduler",
                     :description => "Pass an agent+action to a scheduler that runs it locally",
                     :author      => "Louis Coilliot",
                     :license     => "",
                     :version     => "1.0",
                     :url         => "http://kermit.fr",
                     :timeout     => 10

            @@jobpath = '/tmp/sched'
            @@usock   = '/var/run/sched.sock'                

            action "schedule" do
                validate :agentname, String
                validate :actionname, String

                paramlist = request[:params] ? request[:params].split(',') : [] 
                paramhash = {}
                paramlist.each do |key|
                  paramhash[(key.to_sym rescue key)] = request[(key.to_sym rescue key)]
                end

                schedtype = request[:schedtype] ? request[:schedtype] : 'in'
                schedarg  = request[:schedarg]  ? request[:schedarg]  : '0s'
                
                jobrequest = {
                   :reqtype     => :add,
                   :agent_name  => request[:agentname],
                   :action_name => request[:actionname],
                   :action_args => paramhash,
                   :job_id      => request.uniqid,
                   :job_type    => schedtype,
                   :job_arg     => schedarg,
                }

                send_request(jobrequest)

                reply.data = { :jobid => request.uniqid } 
            end

            action "query" do
                validate :jobid, String
                
                jobrequest = {
                   :reqtype     => :status,
                   :job_id      => request[:jobid],
                }

                reply[:state] = send_request(jobrequest)

                if request[:output] && reply[:state] == "finished"
                  output = get_job_output(request[:jobid])
                  output.keys.each do |key|
                     reply[(key.to_sym rescue key) || key] = output[key]
                  end
                else
                  reply[:output] = "not requested or not (yet ?) available"
                end

            end

            private

            def send_request(jobrequest)
              s = UNIXSocket.new(@@usock)
              s.puts(jobrequest.to_json)
              resp = ''
              while line = s.gets
                       resp = line
                       break # 1st line
              end
              s.close
              resp.chomp
              #EM.run {
              #  EM.connect_unix_domain(@@usock,MCollective::Util::SchedHandler,
              #                         jobrequest.to_json)
              #}
            end

            def lock_n_read(filename)
              output=JSON.dump({:error => 'status file locked'})
              2.times do
                opened = (f= File.open(filename, 'r')).flock(File::LOCK_SH|File::LOCK_NB)
                if opened
                  output = f.read
                  f.flock(File::LOCK_UN)
                  f.close
                  break
                end
                sleep 1
              end
              output
            end

            def get_job_output(jobid)
              filename = "#{@@jobpath}/#{jobid}.out" 
              return 'Output not found' unless File.exists?(filename)
              JSON.parse(lock_n_read(filename))
            end

        end
    end
end
# vi:tabstop=4:expandtab:ai
