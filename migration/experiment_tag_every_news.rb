# this script tags all the news in the database

require 'highscore'
require File.expand_path(File.dirname(__FILE__) + '/../tag.rb')
require File.expand_path(File.dirname(__FILE__) + '/../news.rb')

blacklist = Highscore::Blacklist.load_file 'blacklist.txt'

News.all.each do |i|
  text = Highscore::Content.new i.title, blacklist
  text.configure do
    # ignore short words such as "el", "que", "muy"
    set :short_words_threshold, 3
  end

  item_keys = text.keywords.top(3).map { |item| item.text }

  tags = []
  item_keys.each do |item|
    tag = Tag.where(name: item).take
    if tag.nil?
      tag = Tag.create(name: item)
    end
    tags << tag
  end

  i.tags = tags

  tag_names = tags.map { |i| i.name }
  puts "#{i.news_id} - #{i.title[0...40]} #{tag_names}"
end
