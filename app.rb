require 'sinatra'
require 'json'
require 'active_record'
require 'rumoji'

require './database'
require './fetcher'
require './news'
require './reaction'
require './user'

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

  news.trending_news(params[:date], params[:count].to_i).to_json
end

get '/latest/:date' do
  content_type :json

  news.latest_news_with_reactions(params[:date]).to_json
end

post '/reactions/:news_id' do
  content_type :json

  user = User.where(identifier: params[:user_id], source: params[:source]).first

  if user.nil?
    User.create(identifier: params[:user_id], source: params[:source])
    user = User.where(identifier: params[:user_id], source: params[:source]).first
  end

  emoji = Rumoji.encode(params[:reaction])
  Reaction.create(
    reaction: emoji,
    news_id: params[:news_id],
    user_id: user.user_id
  )
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
