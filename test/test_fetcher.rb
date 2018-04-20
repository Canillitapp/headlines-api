ENV['RACK_ENV'] = 'test'

require 'rack/test'
require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../fetcher.rb')
require File.expand_path(File.dirname(__FILE__) + '/../news.rb')

# FetcherTest
class FetcherTest < Test::Unit::TestCase
  def setup
    @rss = RSS::Maker.make('atom') do |maker|
      maker.channel.author = 'Betzerra'
      maker.channel.updated = Time.now.to_s
      maker.channel.about = 'http://www.ruby-lang.org/en/feeds/news.rss'
      maker.channel.title = 'Example Feed'

      # good url
      maker.items.new_item do |item|
        item.link = 'http://www.betzerra.github.io'
        item.title = 'A new Betzerra was borned'
        item.updated = Time.new(1985, 9, 9, 15, 30, 0, '-03:00')
      end

      # weird url
      maker.items.new_item do |item|
        item.link = 'http://www.perfil.com/http://442.perfil.com/2017-05-04-528861-la-joya-palacios-renovo-su-contrato-con-river-hasta-2021/'
        item.title = 'La joya palacios renovo su contrato con river hasta 2021'
        item.updated = Time.new(1985, 9, 9, 15, 30, 0, '-03:00')
      end

      # weird url 2
      maker.items.new_item do |item|
        item.link = 'stuff'
        item.title = 'This url shouldn\'t work'
        item.updated = Time.new(1985, 9, 9, 15, 30, 0, '-03:00')
      end
    end
  end

  def test_good_url_from_news
    source_uri = URI('http://www.perfil.com/rss/ultimomomento.xml')
    link = NewsFetcher.url_from_news(@rss.items[0], source_uri)

    assert_not_nil(link)

    expected = 'http://www.betzerra.github.io'
    assert_equal(expected, link)
  end

  def test_weird_url_from_news
    source_uri = URI('http://www.perfil.com/rss/ultimomomento.xml')
    link = NewsFetcher.url_from_news(@rss.items[1], source_uri)

    assert_not_nil(link)

    expected = 'http://442.perfil.com/2017-05-04-528861-la-joya-palacios-renovo-su-contrato-con-river-hasta-2021/'
    assert_equal(expected, link)
  end

  def test_weird2_url_from_news
    source_uri = URI('http://www.perfil.com/rss/ultimomomento.xml')
    link = NewsFetcher.url_from_news(@rss.items[2], source_uri)

    assert_not_nil(link)

    expected = 'http://www.perfil.com/stuff'
    assert_equal(expected, link)
  end

  def test_good_image_url
    test_url = 'http://tn.com.ar/show/basicas/el-heredero-el-hijito-de-ricky-fort-le-hizo-honor-su-papa-con-un-gran-y-divertido-gesto_790807'
    fetcher = NewsFetcher.new

    meta = fetcher.meta_from_url(test_url)
    assert_not_nil(meta['image_url'])
  end

  def test_bad_image_url
    test_url = 'http://442.perfil.com/2017-05-04-528775-por-que-se-enojo-buffon-con-los-hinchas-de-la-juventus/'
    fetcher = NewsFetcher.new

    meta = fetcher.meta_from_url(test_url)
    assert_nil(meta['image_url'])
  end

  def test_good_date
    date = NewsFetcher.date_from_news(@rss.items.first)
    assert_equal('495138600', date)
  end

  def test_bad_date
    date = NewsFetcher.date_from_news('stuff')
    assert_nil(date)
  end
end
