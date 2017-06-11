ENV['RACK_ENV'] = 'development'

require './database'
require './news'
require 'metainspector'

def news_without_images
  News.where('img_url IS NULL')
end

def update_news_without_images
  news_without_images.each do |i|
    begin
      page = MetaInspector.new(i.url)
      img_url = page.images.best

      next unless img_url

      i.img_url = img_url
      i.save

      puts "- #{i.news_id}: OK"
    rescue
      next
    end
  end
end

update_news_without_images
