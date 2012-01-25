#!/usr/bin/ruby
require 'rubygems'
require 'json'

abort("Please provide a file containing a job desc.") unless ARGV[0]

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

def lock_n_write(filename, msg)
  (f= File.open(filename, 'w')).flock(File::LOCK_EX)
  f.write(msg)
  f.flock(File::LOCK_UN)
  f.close
end

callpath = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << callpath
$LOAD_PATH << "#{callpath}/lib"

require 'mc-debugger-tk'

configfile = "/etc/mcollective/server.cfg"

McLocal = McDebugger

McLocal.features = {:trace => false}
McLocal.setup(configfile, :info)

fname=ARGV[0]

fic=File.open(fname, 'r')

json = fic.readlines.to_s
job = JSON.parse(json)

jobargs = job['action_args'].symbolize_keys!

res = McLocal.call(job['agent_name'], job['action_name'] , jobargs)

fout="#{fname.chomp(File.extname(fname))}.out"

lock_n_write(fout, res.to_json)

