require './database'
require './news'

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :news

  def self.keywords_from_date(date, quantity)
    date_begin = Date.strptime("#{date} -0300", '%Y-%m-%d %z')
    date_end = date_begin + 1

    Tag
      .select('news_tags.tag_id, count(news_tags.tag_id) as q, tags.name as name')
      .joins(:news)
      .where('date > ?', date_begin.to_time.to_i)
      .where('date < ?', date_end.to_time.to_i)
      .where('tags.blacklisted = 0')
      .group(:tag_id)
      .order('q DESC')
      .limit(quantity)
  end

  def self.starting_with(value)
    Tag
      .where('name LIKE ?', "#{value}%")
      .order('name')
      .limit(20)
  end
end
