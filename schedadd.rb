#!/usr/bin/ruby
require 'rubygems'
require "eventmachine"
require 'json'
require 'uuidtools' # rpm = rubygem-uuidtools

usock = '/tmp/sched.sock'

job_id = UUIDTools::UUID.random_create.to_s

jobrequest = {
               :reqtype     => :add,
               :module_file => 'fib',
               :module_name => 'Fib',
               :method_name => 'fib',
               :method_args => { 'iterations' => 350 },
               :job_id      => job_id,
               :job_type    => :in,
               :job_arg     => '0s',
               :job_options => nil,
             }

#class Handler < EM::Connection
module Handler
  def initialize(msg); @msg = msg;  end

  def post_init; send_data(@msg); end

  #def receive_data(response);end

  def unbind; EM.stop; end
end

EM.run {
  EM.connect_unix_domain(usock, Handler, jobrequest.to_json)
}

puts job_id 
