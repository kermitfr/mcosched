#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'uuidtools' # rpm = rubygem-uuidtools
require 'socket'

usock = '/var/run/sched.sock'

job_id = UUIDTools::UUID.random_create.to_s

jobrequest = {
               :reqtype     => :add,
               :agent_name  => 'nodeinfo',
               :action_name => 'basicinfo',
               :action_args =>  nil,
               :job_id      => job_id,
               :job_type    => :in,
               :job_arg     => '0s',
             }

s = UNIXSocket.new(usock)

s.puts(jobrequest.to_json)

puts $_ while s.gets
s.close
