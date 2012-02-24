#!/usr/bin/env ruby

require 'rubygems'
require 'mcollective'

class MCollective::Agents
   def self.fake_load_agents
     @@agents = {}

     MCollective::Config.instance.libdir.each do |libdir|
       agentdir = "#{libdir}/mcollective/agent"
       next unless File.directory?(agentdir)

       Dir.new(agentdir).grep(/\.rb$/).each do |agent|
         agentname = File.basename(agent, ".rb")
         @@agents[agentname] = 1
       end
     end
   end
end



module McDebugger
# some methods and classes from mc-debugger of ripienaar
# (version from March 09, 2011)
# slightly modified

# Stub connector that just logs
class NoopConnector
    def method_missing(*args)
        MCollective::Logger.debug("connector: #{args.pretty_inspect}")
        true
    end
end

module_function 

def features; @features end
def features= f; @features = f end

def load_agent(agent)
    classname = "MCollective::Agent::#{agent.capitalize}"

    MCollective::PluginManager.delete("#{agent}_agent")

    MCollective::PluginManager.loadclass(classname)
    MCollective::PluginManager << {:type => "#{agent}_agent",
                                   :class => classname}
end

def setup(configfile="server.cfg", loglevel = :debug)
    # stub the connector with a noop one
    MCollective::PluginManager << {:type => "connector_plugin", 
                                   :class => "McDebugger::NoopConnector"}

    logger = MCollective::Logger::Console_logger.new
    MCollective::Log.configure(logger)
    logger.set_level(:fatal)

    config = MCollective::Config.instance
    config.loadconfig(configfile) unless config.configured

    MCollective::Agents.fake_load_agents
    
    logger.set_level(loglevel)
end

def printrpc(agent, action, result)
    ddl ||= MCollective::RPC::DDL.new(agent).action_interface(action.to_s)

    ddl[:display] = :always
    
    puts
    puts MCollective::RPC::Helpers.text_for_result(
      "local_invocation",  result[:statuscode],
       result[:statusmsg], result[:data], ddl)
    puts
rescue Exception => e
    MCollective::Log.warn "Loading the DDL failed: #{e.class}: #{e}"
end

def load_feature(lib, feature)
    require lib
    @features[feature] = true
rescue
end

def colorize(color, msg)
    MCollective::RPC::Helpers.colorize(color, msg)
end

def enable_trace
    filematch   = ["mcollective/agent/", "mcollective/util/", 
                   "mcollective/rpc/reply.rb", "mcollective/rpc/agent.rb"]
    idfilter    = [:method_added]
    eventfilter = ["line"]

    set_trace_func Proc.new {|event, file, line, id, binding, classname|
        next if idfilter.include?(id)
        next if eventfilter.include?(event)
        next unless file =~ /#{filematch.join('|')}/

        msg = "[%8s] %30s %30s (%s:%-2d)" % [event, id, classname, file, line]
        if file =~ /mcollective\/(agent|util)/ or classname.to_s =~ /^MCollective::Agent::/
            puts colorize(:green, msg)
        elsif id == "fail" or id == "fail!"
            puts colorize(:red, msg)
        else
            puts msg
        end
    }
end

def disable_trace
    set_trace_func nil
end

def trace
    @features[:trace] = !@features[:trace]
end

def call(agent, action, request={})
    agent = agent.to_s
    action = action.to_s
    req = {:action => action, :agent  => agent}
    req[:data] = request
    load_agent(agent)
    enable_trace if @features[:trace]
    result = MCollective::PluginManager["#{agent}_agent"].handlemsg(
        {:body => req}, MCollective::PluginManager["connector_plugin"])
    disable_trace if @features[:trace]
    #printrpc(agent, action, result)
    result
end

end
