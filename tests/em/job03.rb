#!/usr/bin/env ruby
require 'rubygems'
require "eventmachine"
require 'json'
require 'uuidtools' # rpm = rubygem-uuidtools

usock = '/tmp/sched.sock'

job_id = UUIDTools::UUID.random_create.to_s

jobrequest = {
               :reqtype     => :add,
               :agent_name  => 'package',
               :action_name => 'yum_clean',
               :action_args =>  nil,
               :job_id      => job_id,
               :job_type    => :in,
               :job_arg     => '0s',
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
