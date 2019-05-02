require 'omnicat/bayes'

require File.expand_path(File.dirname(__FILE__) + '/../category.rb')
require File.expand_path(File.dirname(__FILE__) + '/../news.rb')
require File.expand_path(File.dirname(__FILE__) + '/../source.rb')

OmniCat.configure do |config|
  config.auto_train = :continues
end

DEPORTES_SLUG = 'deportes'
ESPECTACULOS_SLUG = 'espectaculos'
INTERNACIONALES_SLUG = 'internacionales'
POLITICA_SLUG = 'politica'
TECNOLOGIA_SLUG = 'tecnologia'

bayes = OmniCat::Classifiers::Bayes.new
bayes.add_category(ESPECTACULOS_SLUG)
bayes.add_category(INTERNACIONALES_SLUG)
bayes.add_category(POLITICA_SLUG)
bayes.add_category(TECNOLOGIA_SLUG)
bayes.add_category(DEPORTES_SLUG)

News
  .all
  .joins(source: :category)
  .where(categories: { id: 1 })
  .each do |i|

    bayes.train(POLITICA_SLUG, i.title)
  end

News
  .all
  .joins(source: :category)
  .where(categories: { id: 2 })
  .each do |i|

    bayes.train(INTERNACIONALES_SLUG, i.title)
  end

News
  .all
  .joins(source: :category)
  .where(categories: { id: 3 })
  .each do |i|

    bayes.train(TECNOLOGIA_SLUG, i.title)
  end

News
  .all
  .joins(source: :category)
  .where(categories: { id: 4 })
  .each do |i|

    bayes.train(ESPECTACULOS_SLUG, i.title)
  end

News
  .all
  .joins(source: :category)
  .where(categories: { id: 5 })
  .each do |i|

    bayes.train(DEPORTES_SLUG, i.title)
  end

# puts bayes.to_hash

News
  .from_date('2019-04-30', nil)
  .each do |i|

    if i.source.category_id.nil?
      result = bayes.classify(i.title)
      if result.top_score.percentage > 95
        puts("#{result.top_score.key} #{result.top_score.percentage}% - #{i.title}")
      end
    end
  end
