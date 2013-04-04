require 'rubygems'
require 'sinatra'
require 'rack/logger'

configure :development do
  set :logging, Logger::DEBUG
end

set :environment, ENV['RACK_ENV'].to_sym
disable :run, :reload

require './my-librarians.rb'
run Sinatra::Application

