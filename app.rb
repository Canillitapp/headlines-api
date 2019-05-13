require 'sinatra'
require 'json'
require 'active_record'
require 'rumoji'

require './butler'
require './content_view'
require './database'
require './interest'
require './news'
require './reaction'
require './search'
require './source'
require './tag'
require './user'
require './validations'

butler = Butler.new(settings.redis_url)

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
    version: '1.1.0',
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

  butler.trending(date, count.to_i)
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

get '/news' do
  # matches "GET /news?tags=sol,perez&relation=AND"
  content_type :json

  tags = params[:tags].split(',')

  # default relation is OR
  relation = params[:relation] || 'OR'

  result = relation.downcase == 'and' ? News.from_tags_and(tags) : News.from_tags_or(tags)
  result.to_json
end

get '/latest/:date' do
  content_type :json

  page = params[:page].to_i
  butler.latest(params[:date], page)
end

get %r{/popular/([0-9]{4}-[0-9]{2})} do
  date = params[:captures].first

  unless Validations.is_valid_year_month_date(date)
    status 400

    response = {
      error: "invalid date, format must be like '2019-01' (year-month)"
    }
    body response.to_json
    return
  end

  page = [params[:page].to_i, 1].max
  date_begin = Date.strptime(date, '%Y-%m')
  date_end = date_begin >> 1 # >> 1 goes one month in the future

  butler.popular_between(date_begin, date_end, page)
end

get '/popular' do
  content_type :json

  page = [params[:page].to_i, 1].max

  butler.popular(page)
end

post '/reactions/:news_id' do
  content_type :json

  # user_id, source and reaction are mandatory fields
  if params[:user_id].nil? || params[:source].nil? || params[:reaction].nil?
    status 400

    response = {
      error: 'invalid payload'
    }
    body response.to_json
    return
  end

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

  user_id = env['HTTP_USER_ID']
  user_source = env['HTTP_USER_SOURCE']
  keywords = params[:keywords]

  # search tracking
  if !user_id.nil? && !user_source.nil?
    user = User.find_or_create_by(identifier: user_id, source: user_source)
    Search.create(criteria: keywords, user_id: user[:user_id])
  end

  page = [params[:page].to_i, 1].max

  butler.search(keywords, page)
end

get '/search/trending/' do
  content_type :json

  Search
    .select('criteria, count(criteria) as quantity')
    .group(:criteria)
    .order('quantity DESC')
    .limit(10)
    .as_json(except: :id)
    .to_json
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
  content_type :json

  page = [params[:page].to_i, 1].max
  butler.category(params[:id], page)
end

get '/categories/' do
  content_type :json

  categories = Category.all.map do |c|
    category = c.as_json
    news_source = c.sources.joins(:news).first
    unless news_source.nil?
      category['img_url'] = news_source.news.last.img_url
    end
    category
  end
  categories.to_json
end

post '/content-views/' do
  content_type :json

  if params[:user_id].nil? || params[:user_source].nil?
    status 400

    response = { error: 'invalid user' }
    body response.to_json
    return
  end

  user = User
         .where(identifier: params[:user_id], source: params[:user_source])
         .first_or_create

  if user.nil? || params[:news_id].nil?
    status 400

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

get '/tags/:name' do
  content_type :json

  if params[:name].nil?
    status 400

    response = { error: 'invalid or missing parameters' }
    body response.to_json
    return
  end

  Tag
    .starting_with(params[:name])
    .as_json(except: %i[tag_id blacklisted])
    .to_json
end

get '/interests/:user_id/:source' do
  content_type :json

  user = User
           .where(identifier: params[:user_id], source: params[:source])
           .first

  Interest.from_user(user.user_id).to_json
end
