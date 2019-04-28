require 'logger'
require 'rufus-scheduler'

require './butler'
require './category'

CACHE_REFRESH_INTERVAL_DEFAULT = '120s'
TRENDING_COUNT_MOBILE = 6
TRENDING_COUNT_WEB = 12

logger = Logger.new(STDOUT)
scheduler = Rufus::Scheduler.new
butler = Butler.new(ENV['REDIS_URL_FULL'])

interval = ENV['CACHE_REFRESH_INTERVAL'] || CACHE_REFRESH_INTERVAL_DEFAULT

scheduler.every interval, first_in: '3s', overlap: false do
  logger.info('Start update Redis cache')

  # Popular cache (first page)
  butler.popular(1)

  # Trending today cache (web and mobile version)
  date = Date.today.strftime('%Y-%m-%d')
  butler.trending(date, TRENDING_COUNT_MOBILE)
  butler.trending(date, TRENDING_COUNT_WEB)

  # Categories cache (first page)
  Category.all.each do |c|
    butler.category(c.id, 1)
  end

  # Latest news today (all pages)
  butler.latest(date, 0)

  logger.info('End update Redis cache')
end

scheduler.join
