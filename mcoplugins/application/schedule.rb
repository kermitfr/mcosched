require 'pp'
class MCollective::Application::Schedule<MCollective::Application
    description "Wrapper for scheduling actions"
    usage "Usage: mco schedule [options] action package [arguments]"
   
    option :schedtype,
           :description    => "Schedule type : in, at, cron, every",
           :arguments      => ["-s", "--schedtype SCHEDTYPE"],
           :type           => String,
           :required       => false

    option :schedarg,
           :description    => "Arguments of the schedule",
           :arguments      => ["-a", "--args SCHEDARGS"],
           :type           => String,
           :required       => false

    option :query,
           :description    => "Query a job id",
           :arguments      => ["-k", "--jobid JOBID"],
           :type           => String,
           :required       => false 

    option :output,
           :description    => "Displays the output of a finished job",
           :arguments      => ["-o", "--output"],
           :type           => :bool,
           :required       => false 


    def post_option_parser(configuration)
        unless configuration[:query]
          if ARGV.length > 1
              configuration[:agent]  = ARGV.shift
              configuration[:action] = ARGV.shift
              ARGV.each do |v|
                    if v =~ /^(.+?)=(.+)$/
                        configuration[:arguments] = [] unless configuration.include?(:arguments)
                        configuration[:arguments] << v
                    else
                        STDERR.puts("Could not parse argument #{v}")
                    end
              end
          else
              puts("Please specify an agent and action")
              exit 1
          end
          # convert arguments to symbols for keys to comply with simplerpc conventions
          if configuration[:arguments]
              args = configuration[:arguments].clone
              configuration[:arguments] = {}

              args.each do |v|
                  if v =~ /^(.+?)=(.+)$/
                      configuration[:arguments][$1.to_sym] = $2
                  end
              end
          end
        end
    end 

    def validate_configuration(configuration)
        if MCollective::Util.empty_filter?(options[:filter])
            print("Do you really want to operate on packages unfiltered? (y/n): ")
            STDOUT.flush

            exit unless STDIN.gets.chomp =~ /^y$/
        end
    end

    def main
        sched = rpcclient("scheduler")
        
        if configuration[:query]
            jobreq = { :jobid => configuration[:query] }
            if configuration[:output]
                jobreq[:output]='yes'
            end
            sched.query(jobreq).each do |resp|
                if resp[:data]
                  printf("%-40s state=%s\n", resp[:sender], resp[:data][:state])
                  if configuration[:output]
                      pp resp[:data]
                      puts
                  end
                else
                  printf("%-40s state=%s\n", resp[:sender], 'no response')
                end
            end
        else
            configuration[:schedtype] ||='in' 
            configuration[:schedarg]  ||='0s' 
            jobreq = {
                     :agentname  => configuration[:agent],
                     :actionname => configuration[:action],
                     :schedtype  => configuration[:schedtype],
                     :schedarg   => configuration[:schedarg]
                   }
            if configuration[:arguments]
                jobreq[:params] = configuration[:arguments].keys.join(",")
                jobreq.merge!(configuration[:arguments])
            end
            sched.schedule(jobreq).each do |resp|
                if resp[:data]
                    printf("%-40s jobid = %s\n", resp[:sender], resp[:data][:jobid])
                else
                    printf("%-40s error = %s\n", resp[:sender], resp[:statusmsg])
                end
            end
        end

        sched.disconnect
    end
end
# vi:tabstop=4:expandtab:ai
