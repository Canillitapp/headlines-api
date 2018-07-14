ENV['RACK_ENV'] = 'test'

require 'rack/test'
require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../fetcher.rb')
require File.expand_path(File.dirname(__FILE__) + '/../news.rb')
require File.expand_path(File.dirname(__FILE__) + '/../app.rb')

# AppTest
class AppTest < Test::Unit::TestCase
  include Rack::Test::Methods
  self.test_order = :defined

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

  # happy path
  def test_post_content_view
    user = User.first
    params = {
      user_id: user.identifier,
      user_source: user.source,
      news_id: News.first.news_id,
      context_from: 'test'
    }

    post '/content-views/', params
    assert last_response.ok?
  end

  # no user_id should return 400
  def test_post_content_view_400
    user = User.first

    post '/content-views/',
         source: user.source,
         news_id: News.first.news_id

    assert last_response.status == 400
  end
end
