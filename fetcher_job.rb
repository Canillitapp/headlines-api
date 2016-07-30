require 'rufus-scheduler'
require_relative 'fetcher'

news = NewsFetcher.new

scheduler = Rufus::Scheduler.new

scheduler.every '10m', first_in: '3s' do
  news.fetch
end

scheduler.join
