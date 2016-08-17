require 'sinatra'
require 'json'

require_relative 'fetcher'

news = NewsFetcher.new

get '/trending' do
  content_type :json
  news.daily_trending_news.to_json
end

get '/today' do
  content_type :json
  news.today_news.to_json
end
