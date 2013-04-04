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
require 'csv'
require 'rss'

require 'rubygems'
require 'bundler/setup'
require 'rack/cache'
require 'sinatra'

require 'open-uri'

use Rack::Cache

configure do
  begin
    set(:config) { JSON.parse(File.read("config.json")) }
  rescue Exception => e
    puts e
    exit
  end
end

get "/:type" do

  puts params
  puts params[:courses]
  
  cache_control :public, :max_age => 1800 # 30 minutes

  type = params[:type] # Either "subject" or "liaison"
  # programs = params[:splat][0].downcase.split(",") # splat catches the wildcard
  programs = params[:courses].downcase.split(",") # splat catches the wildcard
  puts programs

  logger.info "Type: #{type}"
  logger.info "Programs: #{programs}"

  # We're going to make an RSS feed, so start it.
  rss = RSS::Maker.make("atom") do |maker|
    # TODO Move these into the config file
    maker.channel.author = "York University Libraries"
    maker.channel.updated = Time.now.to_s
    maker.channel.about = "http://www.library.yorku.ca/"
    maker.channel.title = "My Librarian (York University Libraries)"

    open(settings.config["spreadsheet_url"]) do |f|
      unless f.status[0] == "200"
        logger.warn "Cannot load spreadsheet: #{f.status}"
        # TODO Fail nicely
      else
        CSV.parse(f.read, {:headers => true, :header_converters => :symbol}) do |row|
          # row[:librarian], row[:subject_codes], row[:liaison_codes] and row[:url] are now
          # available thanks to those header commands.
          if type == "subject"
            codes = row[:subject_codes]
          elsif type == "liaison"
            codes = row[:liaison_codes]
          end
          if codes.length > 0
            librarian_programs = codes.downcase.split(",")
            overlap = librarian_programs & programs # Elements common to both arrays
            if ! overlap.empty?
              logger.debug "Matched #{row[:librarian]}: #{overlap}"
              maker.items.new_item do |item|
                item.id = row[:librarian].sum.to_s # Checksum, to make a unique ID number
                item.link = row[:url] || "http://www.library.yorku.ca/"
                item.title = row[:librarian]
                item.updated = Time.now.to_s
              end
            end
          end
        end
      end
    end

    logger.debug "Items found: #{maker.items.size}"

    if maker.items.size == 0
      logger.debug "No items found"
      # No matches were found!  Supply the defaults
      # TODO Move all the defaults into the config file
      url = ""
      title = ""
      if type=="subject"
        # TODO Make it so the choice based on whether it's
        # subject or faculty happens below, and works like
        # it does above.  No need for two big blocks.
        programs.each do |program|
          # We're now looping through all of the programs that don't have a known
          # librarian or research help desk.  There will probably only be one
          # but there might be two.
          faculty_code = program[0..1]
          logger.debug "Faculty code: #{faculty_code}"
          default = settings.config["subject_defaults"].find {|f| f["faculty"] == faculty_code }
          if default.nil?
            # None of the known faculties matched, so fall back to the default
            default = settings.config["subject_defaults"].find {|f| f["faculty"] == "default" }
          end
          # Don't list any links twice, so ...
          # Make a list of all of the known titles in the RSS feed so far, and
          # unless the title we want to add is already in the list, add it;
          # but if it is there already, don't add it.
          titles = maker.items.map {|i| i.title}
          # i.title will look like this
          # <title>Librarian Name</title>
          # so we need to match the <title> </title> as well.  Odd.
          unless titles.any? {|t| "<title>#{default["title"]}</title>" =~ /#{t}/}
            maker.items.new_item do |item|
              item.id = default["title"].sum.to_s # Checksum, to make a unique ID number
              item.link = default["url"]
              item.title = default["title"]
              item.updated = Time.now.to_s
            end
          end
        end
      end
    end
  end
  
  content_type 'application/xml'
  rss.to_s

end

get "/*" do
  content_type "text/plain"
  "You need to supply some parameters"
end



#
# Helper methods
#

