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
# The encode! makes it deal with the file as UTF-8, which it is, but it didn't realize.  Some day encoding problems will go away.
CSV.parse(File.read(course_dump_file).encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ''), {:headers => true, :header_converters => :symbol}) do |row|
  code = "#{row[:fac]}/#{row[:subj]}".upcase
  faculty_programs << code unless faculty_programs.include?(code)
end

course_codes = []
# The encode! makes it deal with the file as UTF-8, which it is, but it didn't realize.  Some day encoding problems will go away.
CSV.parse(File.read(course_dump_file).encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ''), {:headers => true, :header_converters => :symbol}) do |row|
  code = "#{row[:fac]}/#{row[:subj]}#{row[:crsnum]}".upcase
  course_codes << code
end

# puts course_codes

list_of_guides_url = 'http://api.libguides.com/api_search.php?iid=1669&type=guides'


open(list_of_guides_url) do |f|
  unless f.status[0] == "200"
    logger.warn "Cannot load URL: #{list_of_guides_url}"
    # TODO Fail nicely
  else
    # This list of all guides (with URLs) isn't a nice RSS feed, it's line after line of HTML <a href>s.
    list_of_guides = f.read
    list_of_guides.split("\n").each do |line|
      url = Nokogiri::HTML(line).css('a').first.attr("href")
      # Now we have the URL of a guide, so we need to load it in an pick out the subject assignments
      begin
        guide_html = open(url).read
      rescue => e
        puts e
      end
      guide = Nokogiri::HTML(guide_html)

      # LibGuides have the author(s) name(s) in the meta author field.
      meta_author  = guide.at("meta[name='author']") #['content']
      if meta_author.nil?
         next
      else
         librarian = meta_author['content']
      end

      # The title is, among other places, in a <span id="guidetitle">.
      if guide.css("span.guidetitle").nil?
        next
      else
        title = guide.css("span.guidetitle").text
      end

      puts "Librarian: #{librarian}"
      puts "Guide: #{title} (#{url})"

      # There are lines in each guide that look like this, and that's where we'll pick out the tags:
      # <span class="guidetags">Tags: <a href="/searchtags.php?iid=1669&amp;tag=s%3Ags%2Fphas">s:gs/phas</a>, <a href="/searchtags.php?iid=1669&amp;tag=s%3Asc%2Fspsc">s:sc/spsc</a></span>
      # <span class="guidetags">Tags: <a href="/searchtags.php?iid=1669&amp;tag=francais">francais</a>, <a href="/searchtags.php?iid=1669&amp;tag=french">french</a></span>
      # The formatting is awkward, but we make do.
      guide.css("h1 span.guidetags").each do |tagline|
        # STDERR.puts "'#{tagline}'"
        tags = tagline.content.gsub("Tags: ", "").split(",")
        # STDERR.puts tags
        next unless tags
        s_tags_ok = []
        s_tags_notok = []
        c_tags_ok = []
        c_tags_notok = []
        c_tags_includes_all = false
        tags.each do |t|
          if /s:/.match(t) # Subject tag
            # String may include ASCII 160  (non-breaking whitespace), which strip doesn't strip, so get medieval on whitespace.
            # http://stackoverflow.com/questions/2588942/convert-non-breaking-spaces-to-spaces-in-ruby
            subject_tag = t.gsub("s:", "").gsub(/[[:space:]]/, "").upcase
            # STDERR.puts "'#{subject_tag}'"
            if faculty_programs.include?(subject_tag)
              s_tags_ok << subject_tag
            else
              s_tags_notok << subject_tag
            end
          elsif /c:/.match(t) # Course tag
            course_tag = t.gsub("c:", "").gsub(/[[:space:]]/, "").upcase
            # STDERR.puts course_tag
            if course_codes.include?(course_tag)
              c_tags_ok << course_tag
            elsif
              course_tag == "ALL"
              c_tags_includes_all = true
            else
              c_tags_notok << course_tag
            end
          end
        end
        puts "Subject: #{s_tags_ok.size + s_tags_notok.size}"
        if s_tags_ok.size > 0
          puts "✓ #{s_tags_ok.size}: " + s_tags_ok.join(" ")
        end
          # s_tags_ok.each do |t|
        #   puts "✓ #{t}"
        # end
        if s_tags_notok.size > 0
          puts "✗ #{s_tags_notok.size}: " + s_tags_notok.join(" ")
        end
        # s_tags_notok.each do |t|
        #   puts "✗ #{t}"
        # end
        next unless (c_tags_ok.size + c_tags_notok.size) > 0
        puts "Courses: #{c_tags_ok.size + c_tags_notok.size}"
        puts "✓ #{c_tags_ok.size}: " + c_tags_ok.join(" ")
        if c_tags_notok.size > 0
          puts "✗ #{c_tags_notok.size}: " + c_tags_notok.join(" ")
        end
          unless c_tags_includes_all
          puts "⚠ missing c:all"
        end
        # c_tags_ok.each do |t|
        #   puts "✓ #{t}"
        # end
        # c_tags_notok.each do |t|
        #   puts "✗ #{t}"
        # end
        #puts "OK: " + tags_ok.join(n")
        #puts "Not OK: " + tags_notok.join(" ")
      end
      puts
      puts
    end
  end
end
