require 'sinatra'
require 'json'
require 'active_record'
require 'rumoji'

require './content_view'
require './database'
require './news'
require './reaction'
require './search'
require './user'
require './validations'

after do
  ActiveRecord::Base.clear_active_connections!
end

before do
  # CORS for Sinatra https://gist.github.com/karlcoelho/17b908942c0837a2d534
  headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
  headers['Access-Control-Allow-Origin'] = '*'
  headers['Access-Control-Allow-Headers'] = 'accept, authorization, origin'
end

options '*' do
  # CORS for Sinatra https://gist.github.com/karlcoelho/17b908942c0837a2d534
  response.headers['Allow'] = 'HEAD,GET,PUT,DELETE,OPTIONS,POST'
  response.headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept'
end

get '/' do
  content_type :json
  {
    version: '1.0',
    author: '@betzerra'
  }.to_json
end

get '/trending/:date' do
  content_type :json

  redirect to("/trending/#{params[:date]}/3")
end

get '/trending/:date/:count' do
  content_type :json

  date  = params[:date]
  count = params[:count]

  unless Validations.is_valid_trending_date(date)
    status 400

    response = {
      error: "invalid trending date, format must be like '2017-01-17' "\
        '(year-month-day)'
    }
    body response.to_json
    return
  end

  unless Validations.is_integer(count)
    status 400

    response = {
      error: 'invalid trending count, must be an integer'
    }
    body response.to_json
    return
  end

  News.trending(date, count.to_i).to_json
end

get '/news/:id' do
  content_type :json

  id = params[:id]

  unless Validations.is_integer(id)
    status 400

    response = {
      error: 'invalid identifier'
    }
    body response.to_json
    return
  end

  News.from_id(id).to_json
end

get '/latest/:date' do
  content_type :json

  News
    .from_date(params[:date])
    .map { |i| News.add_reactions_to_news(i) }
    .to_json
end

get '/popular' do
  content_type :json

  News
    .popular_news
    .map { |i| News.add_reactions_to_news(i) }
    .to_json
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

post '/users/devicetoken' do
  content_type :json

  user = User.find_or_create_by(identifier: params[:user_id], source: params[:source])
  user.device_token = params[:device_token]
  user.save

  user.to_json
end

get '/search/:keywords' do
  content_type :json

  if !env['HTTP_USER_ID'].nil? && !env['HTTP_USER_SOURCE'].nil?

    user = User.where(identifier: env['HTTP_USER_ID'],
                      source: env['HTTP_USER_SOURCE']).first
    Search.create(
      criteria: params[:keywords],
      user_id: user[:user_id]
    )
  end

  News
    .search_news_by_title(params[:keywords])
    .map { |i| News.add_reactions_to_news(i) }
    .to_json(methods: :source_name)
end

get '/reactions/:user_id/:source' do
  content_type :json
  user = User.where(identifier: params[:user_id], source: params[:source]).first
  reactions = Reaction
    .joins(:news)
    .where(user: user)
    .order('date DESC')
    .limit(200)
    .as_json(include: :news)
  reactions.each { |r| r['reaction'] = Rumoji.decode(r['reaction']) }
  reactions.to_json
end

get '/news/category/:id' do
  News.from_category(params[:id]).to_json
end

post '/content-views/' do
  content_type :json

  if params[:user_id].nil? || params[:user_source].nil?
    status 404

    response = { error: 'invalid user' }
    body response.to_json
    return
  end

  user = User
         .where(identifier: params[:user_id], source: params[:user_source])
         .first_or_create

  if user.nil? || params[:news_id].nil?
    status 404

    response = { error: 'invalid or missing parameters' }
    body response.to_json
    return
  end

  content_view = ContentView.create(
    news_id: params[:news_id],
    user_id: user.user_id,
    context_from: params[:context_from]
  )

  { 'content_view' => content_view }.to_json
end
