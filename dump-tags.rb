#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'json'
require 'rss'
require 'open-uri'
require 'nokogiri'
require 'csv'

settings = JSON.parse(File.read("config.json"))

course_dump_file = settings["course_dump_csv"]

faculty_programs = []
librarians = []

# The encode! makes it deal with the file as UTF-8, which it is, but it didn't realize.  Some day encoding problems will go away.
CSV.parse(File.read(course_dump_file).encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ''), {:headers => true, :header_converters => :symbol}) do |row|
  code = "#{row[:fac]}/#{row[:subj]}".upcase
  faculty_programs << code unless faculty_programs.include?(code)
end

list_of_guides_url = 'http://api.libguides.com/api_search.php?iid=1669&type=guides'

# There are lines in each guide that look like this, and that's where we'll pick out the tags:
# <span class="guidetags">Tags: <a href="/searchtags.php?iid=1669&amp;tag=s%3Ags%2Fphas">s:gs/phas</a>, <a href="/searchtags.php?iid=1669&amp;tag=s%3Asc%2Fspsc">s:sc/spsc</a></span>
# <span class="guidetags">Tags: <a href="/searchtags.php?iid=1669&amp;tag=francais">francais</a>, <a href="/searchtags.php?iid=1669&amp;tag=french">french</a></span>

open(list_of_guides_url) do |f|
  unless f.status[0] == "200"
    logger.warn "Cannot load URL: #{list_of_guides_url}"
    # TODO Fail nicely
  else
    list_of_guides = f.read
    list_of_guides.split("\n").each do |line|
      url = Nokogiri::HTML(line).css('a').first.attr("href")
      # Now we have the URL of the guide, so we need to load it in an pick out the subject assignments
      begin
        guide_html = open(url).read
      rescue => e
        puts e
      end
      guide = Nokogiri::HTML(guide_html)

      if guide.css("div.profile_display_name").nil?
        next
      else
        librarian = guide.css("div.profile_display_name").text
      end

      if guide.css("span.guidetitle").nil?
        next
      else
        title = guide.css("span.guidetitle").text
      end

      puts "#{librarian}"
      puts "#{url}"
      puts title

      guide.css("h1 span.guidetags").each do |tagline|
        # STDERR.puts "'#{tagline}'"
        tags = tagline.content.gsub("Tags: ", "").split(",")
        STDERR.puts tags
        next unless tags
        num_tags = tags.size
        tags_ok = []
        tags_notok = []
        tags.each do |t|
          next unless /s:/.match(t)
          # String may include ASCII 160  (non-breaking whitespace), which strip doesn't strip, so get medieval on whitespace.
          # http://stackoverflow.com/questions/2588942/convert-non-breaking-spaces-to-spaces-in-ruby
          subject_tag = t.gsub("s:", "").gsub(/[[:space:]]/, "").upcase
          # STDERR.puts "'#{subject_tag}'"
          if faculty_programs.include?(subject_tag)
            tags_ok << subject_tag
          else
            tags_notok << subject_tag
          end
        end
        puts "Tags: #{num_tags}"
        tags_ok.each do |t|
          puts "✓ " + "'#{t}'"
        end
        tags_notok.each do |t|
          puts "X " + "'#{t}'"
        end
        #puts "OK: " + tags_ok.join(n")
        #puts "Not OK: " + tags_notok.join(" ")
      end
      puts
    end
  end
end
