require 'rufus-scheduler'
require_relative 'fetcher'

news = NewsFetcher.new

scheduler = Rufus::Scheduler.new

scheduler.every '15m', first_in: '3s', overlap: false do
  news.fetch
end

scheduler.join
