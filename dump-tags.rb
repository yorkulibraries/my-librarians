#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rss'
require 'open-uri'
require 'nokogiri'

#                             <span class="guidetags">Tags: <a href="/searchtags.php?iid=&tag=business%20ethics" >business ethics</a>, <a href="/searchtags.php?iid=&tag=business%20morals" >business morals</a>, <a href="/searchtags.php?iid=&tag=corporate%20governance" >corporate governance</a>&nbsp;&nbsp;</span>

list_of_guides_url = 'http://api.libguides.com/api_search.php?iid=1669&type=guides'

# <span class="guidetags">Tags: <a href="/searchtags.php?iid=1669&amp;tag=s%3Ags%2Fphas">s:gs/phas</a>, <a href="/searchtags.php?iid=1669&amp;tag=s%3Asc%2Fspsc">s:sc/spsc</a>  </span>
# <span class="guidetags">Tags: <a href="/searchtags.php?iid=1669&amp;tag=francais">francais</a>, <a href="/searchtags.php?iid=1669&amp;tag=french">french</a>  </span>


open(list_of_guides_url) do |f|
  unless f.status[0] == "200"
    logger.warn "Cannot load URL: #{list_of_guides_url}"
    # TODO Fail nicely
  else
    list_of_guides = f.read
    list_of_guides.split("\n").each do |line|
      url = Nokogiri::HTML(line).css('a').first.attr("href")
      # Now we have the URL of the guide, so we need to load it in an pick out the subject assignments
      guide_html = open(url).read
      puts "got guide_html"
      guide = Nokogiri::HTML(guide_html)
      puts "guide"
      # puts guide
      guide.css("h1 span.guidetags").each do |tagline|
        puts "'#{tagline}'"
        puts tagline.length
        u = Nokogiri::HTML(tagline).css# .css("a").first #each do |u|
        puts u.length
        #end
      end
    end
  end
end
