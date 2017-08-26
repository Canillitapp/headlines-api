require 'sinatra'
require 'json'
require 'active_record'
require 'rumoji'

require './database'
require './fetcher'
require './news'
require './reaction'
require './user'
require './validations'

news = NewsFetcher.new

after do
  ActiveRecord::Base.clear_active_connections!
end

get '/trending/:date' do
  content_type :json

  news.trending_news(params[:date], 3).to_json
end

get '/trending/:date/:count' do
  content_type :json
  date, count = params[:date], params[:count]

  if not Validations.is_valid_trending_date(date) then
    status 400
    body "invalid trending date, format must be like '2017-01-17' (year-month-day)"
    return
  end

  if not Validations.is_valid_trending_count(count) then
    status 400
    body "invalid trending count, must be numeric"
    return
  end

  news.trending_news(date, count.to_i).to_json
end

get '/latest/:date' do
  content_type :json

  news.latest_news_with_reactions(params[:date]).to_json
end

get '/popular' do
  content_type :json

  news.popular_news.to_json
end

post '/reactions/:news_id' do
  content_type :json

  user = User.find_or_create_by(identifier: params[:user_id], source: params[:source])
  emoji = Rumoji.encode(params[:reaction])

  Reaction.react(
    news_id: params[:news_id],
    user_id: user.user_id,
    reaction: emoji
  )

  n = News.find_by_news_id(params[:news_id]).as_json
  n['reactions'] = Reaction.raw_reactions_by_news_id(params[:news_id])
  n.to_json
end

get '/search/:keywords' do
  content_type :json
  News
    .search_news_by_title_with_reactions(params[:keywords])
    .to_json(methods: :source_name)
end

get '/reactions/:user_id/:source' do
  content_type :json
  user = User.where(identifier: params[:user_id], source: params[:source]).first
  reactions = Reaction.joins(:news).where(user: user).reverse_order.as_json(include: :news)
  reactions.each { |r| r['reaction'] = Rumoji.decode(r['reaction']) }
  reactions.to_json
end
