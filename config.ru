require 'rubygems'
require 'sinatra'

set :environment, ENV['RACK_ENV'].to_sym
disable :run, :reload

require './my-librarians.rb'
run Sinatra::Application

