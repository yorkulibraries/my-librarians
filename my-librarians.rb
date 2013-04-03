#!/usr/bin/env ruby

# This file is part of My Librarians.
#
# My Librarians is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# My Librarians is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with My Librarians.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright 2013 William Denton

# CONFIGURING
#
# Configuration details are set in the file config.json.
# Make a copy of config.json.example and edit it.

require 'json'
require 'cgi'
require 'csv'
require 'rss'

require 'rubygems'
require 'bundler/setup'
require 'sinatra'
# require 'rack-cache'

require 'nokogiri'
require 'open-uri'


before do
  # Make this the default
  content_type 'application/xml'
end

configure do
  begin
    set(:config) { JSON.parse(File.read("config.json")) }
  rescue Exception => e
    puts e
    exit
  end
end

spreadsheet_url = settings.config["spreadsheet_url"]

open(spreadsheet_url) do |f|
  unless f.status[0] == "200"
    STDERR.puts f.status
    # TODO Fail nicely
  else
    CSV.parse(f.read, {:headers => true, :header_converters => :symbol}) do |row|
      # row[:librarian], row[:subject_codes], row[:liaison_codes] and row[:url] are now
      # available thanks to those header commands.
      puts row[:librarian]
    end
  end
end

get "/:type/*" do
  type = params[:type] # Either subject or liaison
  # programs = params[:splat].downcase.split(",") # splat catches the wildcard
  # puts programs

  rss = RSS::Maker.make("atom") do |maker|
    maker.channel.author = "York University Libraries"
    maker.channel.updated = Time.now.to_s
    maker.channel.about = "http://www.library.yorku.ca/"
    maker.channel.title = "My Librarian (York University Libraries)"

    maker.items.new_item do |item|
      item.link = "Foo"
      item.title = "Title"
      item.updated = Time.now.to_s
    end
  end

  rss.to_s
end


#
# Helper methods
#

