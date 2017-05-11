ENV['RACK_ENV'] = 'test'

require 'rack/test'
require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../fetcher.rb')
require File.expand_path(File.dirname(__FILE__) + '/../news.rb')
require File.expand_path(File.dirname(__FILE__) + '/../reaction.rb')
require File.expand_path(File.dirname(__FILE__) + '/../app.rb')

# AppTest
class AppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def self.startup
    news = NewsFetcher.new
    news.fetch
  end

  def self.shutdown
    News.destroy_all
    Reaction.destroy_all
  end

  def app
    Sinatra::Application
  end

  def test_trending_default
    get "/trending/#{Time.now.strftime('%Y-%m-%d')}"
    assert last_response.ok?

    parsed_body = JSON.parse(last_response.body)
    assert parsed_body['keywords'].count > 0
    assert parsed_body['news'].count > 0
  end

  def test_trending_custom_quantity
    get "/trending/#{Time.now.strftime('%Y-%m-%d')}/5"
    assert last_response.ok?

    parsed_body = JSON.parse(last_response.body)
    assert parsed_body['keywords'].count > 0
    assert parsed_body['news'].count > 0
  end

  def test_latest
    get "/latest/#{Time.now.strftime('%Y-%m-%d')}"
    assert last_response.ok?

    parsed_body = JSON.parse(last_response.body)
    assert parsed_body.count > 0
  end

  def test_search
    keyword = News.first.title.split.first

    get "/search/#{keyword}"
    assert last_response.ok?

    parsed_body = JSON.parse(last_response.body)
    assert parsed_body.count > 0
  end
end
