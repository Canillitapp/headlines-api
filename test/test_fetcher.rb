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
    assert_not_nil(NewsFetcher.news_image_url(test_url))
  end

  def test_good_date
    date = NewsFetcher.date_from_news(@rss.items.first)
    assert_equal('495138600', date)
  end

  def test_bad_date
    date = NewsFetcher.date_from_news('stuff')
    assert_nil(date)
  end

  def test_good_infobae_spam_dolar
    title = 'Dólar hoy en Nicaragua: cotización del córdoba nicaragüense'\
            'oficial al dólar estadounidense del 4 de marzo (USD/NIO)'
    assert(NewsFetcher.matches_infobae_spam_currency(title))
  end

  def test_not_infobae_spam_dolar
    title = 'Dólar hoy en Argentina: cotización del dólar oficial al dólar'\
            'estadounidense del 4 de marzo (USD/ARS)'
    assert(!NewsFetcher.matches_infobae_spam_currency(title))
  end

  def test_good_infobae_spam_euro
    title = 'Euro hoy en Perú: cotización del nuevo sol al euro del 5 de marzo'\
            '(EUR/PEN)'
    assert(NewsFetcher.matches_infobae_spam_currency(title))
  end

  def test_good_infobae_spam_from_other_newspapers
    title = 'Tapa de Clarín, 9 de Septiembre de 1985'
    assert(NewsFetcher.matches_infobae_spam_from_other_newspapers(title))
  end

  def test_good_infobae_from_agencias
    url = 'https://www.infobae.com/america/agencias/2020/04/17/sam-heughan-de-outlander-habla-contra-el-abuso-en-internet/'
    assert(NewsFetcher .matches_infobae_posts_from_agencias(url))
  end

  def test_bad_infobae_from_agencias
    url = 'https://www.infobae.com/cultura/2020/04/17/viernes-17-de-abril-5-actividades-online-para-disfrutar-en-casa/'
    assert(!NewsFetcher .matches_infobae_posts_from_agencias(url))
  end

  def test_infobae_spam_coronavirus
    # should match
    title = 'Coahuila reporta 25 muertes por COVID-19 y la cifra asciende a 1.212'
    assert(NewsFetcher.matches_infobae_spam_coronavirus(title))

    # should NOT match
    title = 'Coronavirus en Argentina: informan 65 nuevas muertes y el total llega a 6.795'
    assert(!NewsFetcher.matches_infobae_spam_coronavirus(title))
  end

  def test_lanacion_spam_coronavirus
    # should match
    title = 'Coronavirus en Argentina: casos en Bragado, Buenos Aires al 3 de Marzo'
    assert(NewsFetcher.matches_lanacion_spam_coronavirus(title))
  end

  def test_infobae_fallback_image
    fallback_image_1 = 'https://www.infobae.com/pb/resources/assets/img/fallback-promo-image.png'
    assert(NewsFetcher.matches_infobae_fallback_image(fallback_image_1))

    fallback_image_2 = 'https://www.infobae.com/pf/resources/images/fallback-promo-image.png?d=352'
    assert(NewsFetcher.matches_infobae_fallback_image(fallback_image_2))

    regular_image = 'https://www.infobae.com/new-resizer/kJvf-3WK1qZXTVuiqVrJmQrrZYA=/992x774/filters:format(jpg):quality(100)//cloudfront-us-east-1.images.arcpublishing.com/infobae/CEL7JU6GJ5ACDAHBE5JNIO7B6Q.jpg'
    assert(!NewsFetcher.matches_infobae_fallback_image(regular_image))
  end
end
