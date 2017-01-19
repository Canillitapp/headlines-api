require 'rufus-scheduler'
require 'json'
require_relative 'fetcher'

news = NewsFetcher.new
# news.fetch

# puts news.trending_news('2017-01-18', 3).to_json
# puts news.latest_news('2017-01-18').to_json

news.latest_news('2017-01-18').each do |i|
  puts "#{Time.at(i.date).to_datetime} - #{i.title}"
end

# scheduler = Rufus::Scheduler.new
#
# scheduler.every '10m', first_in: '3s' do
#   news.fetch
# end
#
# scheduler.join

# puts news.daily_trending_news
