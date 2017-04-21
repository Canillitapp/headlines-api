require './database'
require './source'

class News < ActiveRecord::Base
  belongs_to :source
  delegate :name, :to => :source, :prefix => true

  def self.search_news_by_title(search)
    News.where('title LIKE ?', "%#{search}%").order('date DESC').limit(200)
  end
end
