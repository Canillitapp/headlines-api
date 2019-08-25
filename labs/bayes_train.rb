require 'omnicat/bayes'

require File.expand_path(File.dirname(__FILE__) + '/../category.rb')
require File.expand_path(File.dirname(__FILE__) + '/../news.rb')
require File.expand_path(File.dirname(__FILE__) + '/../source.rb')

stopwords_path = File.expand_path(File.dirname(__FILE__) + '/stopwords_es.txt')
stopwords = File.foreach(stopwords_path).map(&:chomp)

OmniCat.configure do |config|
  config.auto_train = :continues
  config.exclude_tokens = stopwords
end

DEPORTES_SLUG = 'deportes'
DEPORTES_ID = 5
ESPECTACULOS_SLUG = 'espectaculos'
ESPECTACULOS_ID = 4
INTERNACIONALES_SLUG = 'internacionales'
INTERNACIONALES_ID = 2
POLITICA_SLUG = 'politica'
POLITICA_ID = 1
TECNOLOGIA_SLUG = 'tecnologia'
TECNOLOGIA_ID = 3
TRAIN_NEWS_LIMIT = 3000
CLASSIFY_THRESHOLD = 90

def train_bayes(bayes, category_id, slug)
  News
    .all
    .joins(source: :category)
    .where(categories: { id: category_id })
    .order(news_id: :desc)
    .limit(TRAIN_NEWS_LIMIT)
    .each do |i|

      bayes.train(slug, i.title)
    end
end

bayes = OmniCat::Classifiers::Bayes.new
bayes.add_category(ESPECTACULOS_SLUG)
bayes.add_category(INTERNACIONALES_SLUG)
bayes.add_category(POLITICA_SLUG)
bayes.add_category(TECNOLOGIA_SLUG)
bayes.add_category(DEPORTES_SLUG)

train_bayes(bayes, DEPORTES_ID, DEPORTES_SLUG)
train_bayes(bayes, ESPECTACULOS_ID, ESPECTACULOS_SLUG)
train_bayes(bayes, INTERNACIONALES_ID, INTERNACIONALES_SLUG)
train_bayes(bayes, POLITICA_ID, POLITICA_SLUG)
train_bayes(bayes, TECNOLOGIA_ID, TECNOLOGIA_SLUG)

# puts bayes.to_hash

News
  .from_date('2019-05-12', nil)
  .each do |i|

    if i.source.category_id.nil?
      result = bayes.classify(i.title)
      if result.top_score.percentage > CLASSIFY_THRESHOLD
        puts("#{result.top_score.key} #{result.top_score.percentage}% - #{i.title}")
      end
    end
  end
