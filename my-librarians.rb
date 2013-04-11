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

# See README.md for details.

# Usage: /subject?courses=2012_HH_PSYC_F_2030__3_A_EN_A_LECT_01,2012_SC_CSE_F_1710__3_A_EN_A_LAB_03
# or
# /subject?tag=hh/psyc,ap/sosc

# TODO Brief explanation here.

# Course codes look like this (for "Romain Elegaic Poetry"):
# 2012_AP_IT_Y_2751__9_A_EN_A_LECT_01
#
# Year           : 2012
# Faculty        : AP
# Subject        : IT
# Period         : Y (F = fall, W = winter, SU, S1, S2 = summer)
# ID             : 2751
# Rubric variance: _ (if it is blank, replace with an extra underscore)
# Credit weight  : 9
# Section        : A
# Language       : EN
# Course type    : A (internal code)
# Format         : LECT
# Group          : 01

# Eris and variables passed over
#
# When Eris calls a web service it passes over course codes in their
# complete form and also broken up into parts, like so:
#
# "GET /something?
# courses=2012_AP_SOSC_Y_1341__9_A_EN_A_LECT_01
# &tag=SOSC_1341,AP/SOSC,AP/sosc1341,2012_AP_SOSC_Y_1341__9_A_EN_A_LECT_01
# &program_codes=SOSC_1341,AP/SOSC,AP/sosc1341
#
# The rule here is that if courses is passed in, we will use it exclusively
# and ignore other variables, which are a mess.
# However, if tag exists alone, we will use it.

# Other good course codes:
# 2012_HH_PSYC_F_2030__3_A_EN_A_LECT_01 (Introductio to Research Methods)
# 2012_SC_CSE_F_1710__3_A_EN_A_LAB_03 (Programming for Digital Media)

# (Note to self regarding other services:
# "The moodle service breaks the standard course codes into relevant
# pieces and passes them to the underlying feeds."
# E.g. http://www.library.yorku.ca/eris/fetch/tagged_urls.rss?prefix=s&tag=ap/it

# Note about tests:
# Some Sinatra examples here: http://rubysource.com/writing-a-feed-aggregator-with-sinatra/

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

  # Thank you Rack::Cache for making this easy.  We don't want to
  # hammer Google Drive every time we get a request, so cache any
  # results for 30 minutes.
  cache_control :public, :max_age => 1800 # 30 minutes

  type = params[:type] # Either "subject" or "liaison"

  programs = []

  if params[:courses]
    # If the courses parameter is passed in, used it;
    # if not, look for tag.
    params[:courses].split(",").each do |coursecode|
      begin
        elements = /(\d{4})_(\w*)_(\w*)_(\w*)_(\d*)_(.)(\d)_(\w)_(\w{2})_(\w)_(\w*)_(\d{2})/.match(coursecode)
        raise "ERROR: Bad course code #{coursecode}" if elements.nil?
        faculty_code = elements[2]
        program_code = elements[3]
        programs.push("#{faculty_code}/#{program_code}")
      rescue Exception => e
        logger.warn e
      end
    end
  elsif params[:tag]
    programs = params[:tag].downcase.split(",")
  end

  logger.info "Type: #{type}"
  logger.info "Programs: #{programs}"

  # We're going to make an RSS feed, so start it.
  rss = RSS::Maker.make("atom") do |maker|
    # TODO Move these into the config file
    maker.channel.author = "York University Libraries"
    maker.channel.updated = Time.now.to_s
    maker.channel.about = "http://www.library.yorku.ca/"
    maker.channel.title = "My Librarian (York University Libraries)"

    begin
      # The request to Google Drive to read the spreadsheet might
      # fail, so be careful.
      open(settings.config["spreadsheet_url"]) do |f|
        unless f.status[0] == "200"
          logger.warn "Cannot load spreadsheet: #{f.status}"
        else
          CSV.parse(f.read, {:headers => true, :header_converters => :symbol}) do |row|
            # row[:librarian], row[:subject_codes], row[:liaison_codes] and row[:url] are now
            # available thanks to those header commands.
            if type == "subject"
              codes = row[:subject_codes] || ""
            elsif type == "liaison"
              codes = row[:liaison_codes] || ""
            end
            if codes.length > 0
              librarian_programs = codes.downcase.split(",")
              programs.each do |p|
                # For each program passed in, see if there's an
                # exact match for it in this librarian's list of
                # what they cover, or if it matches a wildcard.
                p_faculty = p[0..1]
                if librarian_programs.include? p or librarian_programs.include? "#{p_faculty}/*"
                  logger.debug "Matched #{row[:librarian]}: #{p}"
                  # If it does match, don't add it if the librarian is already
                  # in the RSS feed.  Use the checksum in the id field to confirm.
                  known_ids = maker.items.map {|i| i.id}
                  unless known_ids.any? {|id| "<id>#{row[:librarian].sum.to_s}</id>" =~ /#{id}/}
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
        end
      end
    rescue Exception => e
      logger.warn e
      # TODO Show an error message to the user.  Can't connect to Google!?
    end

    # logger.debug "Items found: #{maker.items.size}"

    if maker.items.size == 0
      # No matches were found!  Supply the defaults
      logger.debug "No items found; adding in defaults"
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

  # TODO What if none of that matched and the RSS feed still has 0 items?
  # Supply the default, just in case.

  content_type 'application/xml'
  rss.to_s

end

get "/*" do
  content_type "text/plain"
  "You need to supply some parameters.  See https://github.com/yorkulibraries/my-librarians"
end



#
# Helper methods
#

