require 'rufus-scheduler'
require_relative 'fetcher'

news = NewsFetcher.new

scheduler = Rufus::Scheduler.new

interval = ENV['FETCHER_INTERVAL'] || '25m'

scheduler.every interval, first_in: '3s', overlap: false do
  news.fetch
end

scheduler.join
