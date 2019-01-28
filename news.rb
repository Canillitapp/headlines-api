require './database'
require './source'
require './reaction'
require './tag'
require './content_view'

class News < ActiveRecord::Base
  belongs_to :source
  has_many :reaction
  has_and_belongs_to_many :tags
  has_many :content_view
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
      .select('news.*')
      .where('reactions_count > 0 OR content_views_count > 1')
      .group('news.news_id')
      .order('date DESC')
      .limit(50)
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

  def self.from_tags_and(tags)
    News
      .select('news.*, count(news.news_id) as matches')
      .joins(:tags)
      .where('tags.name' => tags)
      .group(:news_id)
      .order('matches DESC, date DESC')
      .limit(50)
  end

  def self.from_tags_or(tags)
    News
      .select('news.*')
      .joins(:tags)
      .where('tags.name' => tags)
      .order('date DESC')
      .limit(50)
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

  def self.trending(date, count)
    keywords = Tag.keywords_from_date(date, count * 3)

    date_begin = Date.strptime("#{date} -0300", '%Y-%m-%d %z')
    date_end = date_begin + 1

    keywords_ids = keywords.map { |i| i.tag_id }
    keywords_names = keywords.map { |i| i.name }

    news = News
           .select('news.*, tags.tag_id, tags.name')
           .joins(:tags)
           .where('date > ?', date_begin.to_time.to_i)
           .where('date < ?', date_end.to_time.to_i)
           .where('news_tags.tag_id' => keywords_ids)
           .order('date DESC')

    trending = {}
    keywords_names.each do |k|
      trending[k.to_s] = []
    end

    news.each do |i|
      keywords_names.each do |k|
        # remove any kind of punctuation on title so it's possible to match
        # "tarifa," with keyword "tarifa"
        if i.title.gsub(/[^[:word:]\s]/, '').split(' ').include? k
          trending[k.to_s] << i
        end
      end
    end

    # remove duplicate news
    trending.each_value { |v| v.uniq! }

    # sort keywords (first has more items)
    ordered_keywords = keywords_names.sort do |x, y|
      trending[y.to_s].length <=> trending[x.to_s].length
    end

    # remove elements that are in more than one trending item
    ordered_keywords.each do |k1|
      trending[k1].each do |v1|
        ordered_keywords.each do |k2|
          next if k1 == k2
          trending[k2].delete_if { |v2| v1.news_id == v2.news_id }
        end
      end
    end

    # sort keywords again (first has more items)
    ordered_keywords = keywords_names.sort do |x, y|
      trending[y.to_s].length <=> trending[x.to_s].length
    end

    # debug
    # ordered_keywords.each { |k| @logger.debug "#{k} (#{trending[k].length})" }

    # take 'count' keywords
    ordered_keywords = ordered_keywords.take(count).map(&:to_s)

    # ignore keywords that doesn't contain a news
    ordered_keywords = ordered_keywords.select { |k| trending[k].length > 0 }

    trending = trending.select do |k, _|
      ordered_keywords.include? k.to_s
    end

    # add reactions and source_name to every news
    trending.each do |k, v|
      trending[k] = v.map { |i| News.add_reactions_to_news(i) }
    end

    { 'keywords' => ordered_keywords, 'news' => trending }
  end
end
