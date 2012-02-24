#!/usr/bin/env ruby
require 'pp'

callpath = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << callpath
$LOAD_PATH << "#{callpath}/lib"

require 'mc-debugger-tk'

configfile = "/etc/mcollective/server.cfg"

McLocal = McDebugger

McLocal.features = {:trace => false}
McLocal.setup(configfile, :info)

pp McLocal.call('rpcutil', 'ping')

#pp McLocal.call('rpcutil', 'get_fact', :fact => 'hostname')
#pp McLocal.call('package', 'status', :package => 'bash')
#pp McLocal.call('package', 'yum_clean')
#pp McLocal.call('rpcutil', 'inventory')
#pp McLocal.call('package', 'yum_checkupdates')
#pp McLocal.call('nodeinfo', 'basicinfo')
