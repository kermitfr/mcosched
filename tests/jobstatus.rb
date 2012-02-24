#!/usr/bin/ruby
require 'rubygems'
require 'json'
require 'socket'

usock = '/var/run/sched.sock'

(puts 'Please provide a job id'; exit) unless ARGV[0]

jobrequest = { :reqtype => :status, :job_id => ARGV[0] }

s = UNIXSocket.new(usock)
#s = TCPSocket.new('localhost',942)

s.puts(jobrequest.to_json)
while line = s.gets
    puts line
end
s.close


