require 'json'
require 'logger'
require 'omnicat/bayes'
require 'redis'

require './category.rb'
require './news.rb'
require './source.rb'

CACHED_BAYES_REDIS_KEY = 'categories_bayes'
TRAIN_NEWS_LIMIT = 3000
CLASSIFY_THRESHOLD = 90

class BayesTrainer

  def initialize(redis_url)
    @logger = Logger.new(STDOUT)
    @redis = Redis.new(url: redis_url) unless redis_url.nil?

    cached = cached_bayes
    if cached.nil?
      @logger.info "#{CACHED_BAYES_REDIS_KEY} was nil, going to retrain"
      @bayes = trained_bayes
      save_bayes(@bayes)
    else
      @logger.info "loaded cached #{CACHED_BAYES_REDIS_KEY}"
      @bayes = cached
    end
  end

  def cached_bayes
    return nil if @redis.nil?

    data = @redis.get(CACHED_BAYES_REDIS_KEY)
    return nil if data.nil?

    data = JSON.parse(data).with_indifferent_access
    bayes = OmniCat::Classifiers::Bayes.new(data)
    bayes
  end

  def save_bayes(bayes)
    return if @redis.nil?

    @redis.set(CACHED_BAYES_REDIS_KEY, bayes.to_hash.to_json)
  end

  def train_bayes(bayes, category_id)
    News
      .all
      .joins(source: :category)
      .where(categories: { id: category_id })
      .order(news_id: :desc)
      .limit(TRAIN_NEWS_LIMIT)
      .each do |i|

        bayes.train(category_id, i.title)
      end
  end

  def trained_bayes
    stopwords_path = './assets/stopwords_es.txt'
    stopwords = File.foreach(stopwords_path).map(&:chomp)
    @logger.info 'loaded stopwords'

    @logger.info 'start training'
    OmniCat.configure do |config|
      config.auto_train = :continues
      config.exclude_tokens = stopwords
    end

    bayes = OmniCat::Classifiers::Bayes.new

    Category.all.each do |c|
      bayes.add_category(c.id)
      train_bayes(bayes, c.id)
    end

    @logger.info 'end training'
    bayes
  end

  def classify_title(title)
    r = @bayes.classify(title)
    r.top_score.percentage > CLASSIFY_THRESHOLD ? r.top_score.key : nil
  end
end
