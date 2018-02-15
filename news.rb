require './database'
require './source'
require './reaction'
require './tag'

class News < ActiveRecord::Base
  belongs_to :source
  has_many :reaction
  has_and_belongs_to_many :tags
  delegate :name, :to => :source, :prefix => true

  def self.add_reactions_to_news(n)
    # convert the ActiveRecord to a hash despite its confusing name
    # then add the source_name 'property'
    tmp = n.as_json
    tmp['source_name'] = n.source_name
    tmp['category'] = n.source.category_name
    tmp['reactions'] = Reaction.raw_reactions_by_news_id(n.news_id)
    tmp
  end

  def self.search_news_by_title(search)
    News
      .where('LOWER(title) LIKE ?', "%#{search.downcase}%")
      .order('date DESC')
      .limit(200)
  end

  def self.popular_news
    News
      .select('news.*, count(reactions.reaction_id) as total_reactions')
      .joins(:reaction)
      .group('news.news_id')
      .having('total_reactions > 0')
      .order('date DESC')
      .limit(200)
  end

  def self.from_date(date)
    date_begin = Date.strptime("#{date} -0300", '%Y-%m-%d %z')
    date_end = date_begin + 1

    News
      .where('date > ?', date_begin.to_time.to_i)
      .where('date < ?', date_end.to_time.to_i)
      .order('date DESC')
  end

  def self.from_id(id)
    News.add_reactions_to_news(News.find(id))
  end

  def self.from_category(id)
    # see nested asociations on .joins
    # http://guides.rubyonrails.org/active_record_querying.html
    news = News
      .joins(source: :category)
      .where(categories: { id: id })
      .order('date DESC')
      .limit(50)

    news.map { |i| News.add_reactions_to_news(i) }
  end
end
