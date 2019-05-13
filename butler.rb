require 'logger'
require 'redis'

require './news'

class Butler
  REDIS_TIMEOUT = 450

  def initialize(url)
    unless url.nil?
      @redis = Redis.new(url: url)
    end

    @logger = Logger.new(STDOUT)
  end

  def get(key)
    if @redis.nil?
      result = yield
      return result
    end

    unless block_given?
      @logger.warn 'No block given'
      return
    end

    begin
      result = @redis.get(key)
      if result.nil?
        result = yield
        @redis.set(key, result, ex: REDIS_TIMEOUT)
      end
      result

    rescue => e
      @logger.warn e.inspect
      yield
    end
  end

  def trending(date, q)
    redis_key = "trending_#{date}_#{q}"

    get(redis_key) { News.trending(date, q).to_json }
  end

  def popular(page)
    redis_key = "popular_#{page}"

    get(redis_key) do
      News
        .popular_news(page)
        .map { |i| News.add_reactions_to_news(i) }
        .to_json
    end
  end

  def popular_between(date_begin, date_end, page)
    redis_key = "popular_#{date_begin}_#{date_end}_#{page}"

    get(redis_key) do
      News
        .popular_news_between(date_begin, date_end, page)
        .map { |i| News.add_reactions_to_news(i) }
        .to_json
    end
  end

  def category(id, page)
    redis_key = "category_#{id}_#{page}"

    get(redis_key) { News.from_category(id, page).to_json }
  end

  def latest(date, page)
    redis_key = "latest_#{date}_#{page}"

    get(redis_key) do
      News
          .from_date(date, page)
          .map { |i| News.add_reactions_to_news(i) }
          .to_json
    end
  end

  def search(keywords, page)
    redis_key = "search_#{keywords}_#{page}"

    get(redis_key) do
      News
        .search_news_by_title(keywords, page)
        .map { |i| News.add_reactions_to_news(i) }
        .to_json(methods: :source_name)
    end
  end
end
