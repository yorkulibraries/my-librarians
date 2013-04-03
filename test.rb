#!/usr/bin/env ruby

require './my-librarians.rb'
require 'test/unit'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

class FirstTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_it_gets_google_spreadsheet
    # get '/'
    # assert last_response.ok?
    # assert_equal 'Hello World', last_response.body
  end

  def test_it_responds_to_hh_psyc
    get '/', :courses => 'hh_psyc'
    assert last_response.body.include?('Adam')
  end
end
