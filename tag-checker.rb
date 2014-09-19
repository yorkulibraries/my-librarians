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

structure = Hash.new

# puts course_codes

list_of_guides_url = 'http://api.libguides.com/api_search.php?iid=1669&type=guides'

puts <<TOP
<html>
<meta charset="utf-8">
<head>
<title>LibGuides tag check</title>
</head>

<body>

<h1>LibGuides tag check</h1>

<p>

This report checks subject and course tags against the <a href="https://github.com/yorkulibraries/my-librarians/blob/master/public/2014-courses-fw.csv">2014 fall-winter course list</a>. Incorrect subject or course tags don't break anything, but missing ones mean the guides won't show up in the right places to students.  See <a href="http://researchguides.library.yorku.ca/content.php?pid=272580&sid=2790144">Tagging guides for programs and courses</a> for more about this.

</p>

<p>

In faculty codes, AP = LA&amp;PS. AS (Arts) and AK (Atkinson) no longer exist. Any of those tags should be removed and replaced with the current AP subject tags.

</p>

<p>

About course tags: "⚠ c:all missing" means a course guide is not tagged with "c:all", which is necessary to make it appear on the <a href="http://researchguides.library.yorku.ca/courses">list of all course guides</a>.  "Sections ?" means there is a long-form course code, which we use to narrow a course guide down to a specific section, but the validity must be checked by hand (there is no automatic way of verifying a course code like that is valid).

</p>

TOP

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

      structure[librarian] = Hash.new if structure["librarian"].nil?
      structure[librarian]["name"] = librarian

      # The title is, among other places, in a <span id="guidetitle">.
      if guide.css("span.guidetitle").nil?
        next
      else
        title = guide.css("span.guidetitle").text.gsub(/[[:space:]]$/, "") # Eliminate whitespace, including non-breaking, at the end of the title.

      end

      STDERR.puts "#{librarian} ... #{title} (#{url})"

      puts %Q(<p><b>#{librarian}</b>: <a href="#{url}">#{title}</a><br />)

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
        c_tags_unknown = []
        c_tags_includes_all = false
        tags.each do |t|
          if /s:/.match(t) # Subject tag
            # String may include ASCII 160  (non-breaking whitespace), which strip doesn't strip, so get medieval on whitespace.
            # http://stackoverflow.com/questions/2588942/convert-non-breaking-spaces-to-spaces-in-ruby
            subject_tag = t.gsub("s:", "").gsub(/[[:space:]]/, "").upcase
            # STDERR.puts "'#{subject_tag}'"
            if faculty_programs.include?(subject_tag)
              s_tags_ok << subject_tag
            elsif /\/\*$/.match(subject_tag) # It's a wildcard ending in /*, such as ES/*
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
            elsif /(\d{4})_(\w*)_(\w*)_(\w*)_(\d*)_(.)(\d)_(\w)_(\w{2})_(\w)_(\w*)_(\d{2})/.match(course_tag)
              c_tags_unknown << course_tag
            else
              c_tags_notok << course_tag
            end
          end
        end

        # Some character encoding problem (!) meant UTF-8 checks and Xs weren't showing properly in the browser, so I use HTML entities:
        # ✓ = &#x2713;
        # ✗ = &#x2717;

        # STDERR.puts "Subject: #{s_tags_ok.size + s_tags_notok.size}"
        if s_tags_ok.size > 0
          # STDERR.puts "✓ #{s_tags_ok.size}: " + s_tags_ok.join(" ")
          puts "Subjects ✓ " + s_tags_ok.join(" ") + "<br />"
        end
          # s_tags_ok.each do |t|
        #   puts "✓ #{t}"
        # end
        if s_tags_notok.size > 0
          # STDERR.puts "✗ #{s_tags_notok.size}: " + s_tags_notok.join(" ")
          puts "Subjects ✗ " + s_tags_notok.join(" ") + "<br />"
        end
        # s_tags_notok.each do |t|
        #   puts "✗ #{t}"
        # end
        next unless (c_tags_ok.size + c_tags_notok.size) > 0
        # STDERR.puts "Courses: #{c_tags_ok.size + c_tags_notok.size}"
        # puts "✓ #{c_tags_ok.size}: " + c_tags_ok.join(" ")
        if c_tags_ok.size > 0
          puts "Courses ✓ " + c_tags_ok.join(" ") + "<br />"
        end

        if c_tags_notok.size > 0
          puts "Courses ✗ " + c_tags_notok.join(" ") + "<br />"
          # puts "✗ #{c_tags_notok.size}: " + c_tags_notok.join(" ")
        end

        if c_tags_unknown.size > 0
          puts "Sections ? " + c_tags_unknown.join(" ") + "<br />"
          # puts "✗ #{c_tags_notok.size}: " + c_tags_notok.join(" ")
        end

        if (c_tags_ok.size + c_tags_notok.size) > 0
          if c_tags_includes_all
            # puts "<td>✓</td>"
          else
            puts "⚠ c:all missing<br />"
          end
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
    end
    puts "</p>"
  end
end

puts "</body></html>"
