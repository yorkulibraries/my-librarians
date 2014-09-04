#!/usr/bin/env ruby

# Frequency count of words used in course titles

require 'json'
require 'csv'
require 'open-uri'

settings = JSON.parse(File.read("config.json"))

course_dump_file = settings["course_dump_csv"]

frequency = Hash.new(0)

CSV.parse(File.read(course_dump_file).encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ''), {:headers => true, :header_converters => :symbol}) do |row|
  row[:longtitle].split.each { |word|  frequency[word] += 1}
end

frequency.sort_by {|x,y| y }.reverse.each {|w, f| puts f.to_s + ' ' + w}
