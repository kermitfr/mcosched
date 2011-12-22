#!/usr/bin/ruby
require 'rubygems'
require "eventmachine"
require 'json'

usock = '/tmp/sched.sock'

unless ARGV[0]
  puts 'Please provide a job id'
  exit
end

jobrequest = {
               :reqtype     => :status,
               :job_id      => ARGV[0],
             }

#class Handler < EM::Connection
module Handler
  def initialize(msg); @msg = msg; end

  def post_init; send_data(@msg); end

  def receive_data(response)
    puts response
  end

  def unbind; EM.stop; end
end

EM.run {
  begin
    EM.connect_unix_domain(usock, Handler, jobrequest.to_json)
  rescue RuntimeError
    puts "Runtime Error - No scheduler server found ?"
    exit
  end
}


