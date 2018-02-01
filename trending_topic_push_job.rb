require 'rufus-scheduler'
require_relative 'trending_topic_push'

scheduler = Rufus::Scheduler.new

scheduler.cron '0 10,18 * * *' do
  date = Time.now.strftime('%Y-%m-%d')
  push_trending_news(date)
end

scheduler.join
