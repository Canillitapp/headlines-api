require 'rufus-scheduler'
require 'json'
require_relative 'fetcher'

news = NewsFetcher.new
# news.fetch
# puts news.trending_news('2016-09-09', 3).to_json

# scheduler = Rufus::Scheduler.new
#
# scheduler.every '10m', first_in: '3s' do
#   news.fetch
# end
#
# scheduler.join

# puts news.daily_trending_news
