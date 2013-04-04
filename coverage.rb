#!/usr/bin/env ruby

require 'json'
require 'csv'
require 'open-uri'

settings = JSON.parse(File.read("config.json"))

course_dump = "2012-courses-fw.csv"

faculty_programs = []
librarians = []

CSV.parse(File.read(course_dump), {:headers => true, :header_converters => :symbol}) do |row|
  code = "#{row[:fac]}/#{row[:subj]}".upcase
  faculty_programs << code unless faculty_programs.include?(code)
end

faculty_programs.sort!

#puts faculty_programs
#exit

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
  subjects_covered << l[:subject_codes].upcase.split(",")  unless l[:subject_codes].nil?
end

subjects_covered.flatten!.sort!

# exit

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

