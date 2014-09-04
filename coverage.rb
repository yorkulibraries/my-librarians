#!/usr/bin/env ruby

require 'json'
require 'csv'
require 'open-uri'

settings = JSON.parse(File.read("config.json"))

# Ranges file can either be local or on the web.
course_dump_file = ARGV.shift
abort 'Please specify course dump file' unless course_dump_file

faculty_programs = []
librarians = []

# The encode! makes it deal with the file as UTF-8, which it is, but it didn't realize.  Some day encoding problems will go away.
CSV.parse(File.read(course_dump_file).encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ''), {:headers => true, :header_converters => :symbol}) do |row|
  code = "#{row[:fac]}/#{row[:subj]}".upcase
  faculty_programs << code unless faculty_programs.include?(code)
end

faculty_programs.sort!

open(settings["spreadsheet_url"]) do |f|
  unless f.status[0] == "200"
    logger.warn "Cannot load spreadsheet: #{f.status}"
    # TODO Fail nicely
  else
    librarians = CSV.parse(f.read, {:headers => true, :header_converters => :symbol})
  end
end

subjects_covered = []

librarians.each do |l|
  subjects_covered << l[:subject_codes].rstrip.upcase.split(",")  unless l[:subject_codes].nil?
end

subjects_covered.flatten!.sort!

not_covered = []

faculty_programs.each do |fp|
  # Easy: if we're checking HH/PSYC and HH/PSYC is in the list of
  # subjects covered, we're done.
  next if subjects_covered.include?(fp)
  # But what if we're checking SB/MGMT and SB/* is in the list?
  faculty_code = fp[0..1]
  faculty_code_wildcard = faculty_code + "/*"
  next if subjects_covered.include?(faculty_code_wildcard)
  not_covered << fp
end

STDERR.puts "Faculty/programs known: #{faculty_programs.size}"
STDERR.puts "Subjects covered (including wildcards): #{subjects_covered.size}"
STDERR.puts "Faculty/programs not covered: #{not_covered.size}"

puts not_covered
