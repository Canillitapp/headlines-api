require 'logger'
require 'rufus-scheduler'
require_relative 'trending_topic_push'

scheduler = Rufus::Scheduler.new
logger = Logger.new(STDOUT)

scheduler.cron '0 10,18 * * *' do
  logger.debug('starts push notification process')
  date = Time.now.strftime('%Y-%m-%d')
  push_trending_news(date)
end

scheduler.join
