require 'rss'
require 'open-uri'
require 'sanitize'
require 'logger'
require 'highscore'
require 'uri'
require 'metainspector'
require 'i18n'

require './bayes_trainer'
require './news'
require './source'

# NewsFetcher
class NewsFetcher
  def initialize
    @logger = Logger.new(STDOUT)
    @blacklist = Highscore::Blacklist.load_file 'blacklist.txt'

    redis_url = ENV['REDIS_URL_FULL']

    unless Sinatra::Application.environment == :test
      @bayes_trainer = BayesTrainer.new(redis_url)
    end
  end

  def self.url_from_news(item, feed_uri)
    link_url = if item.link.is_a? RSS::Atom::Feed::Link
                 item.link.href
               else
                 Sanitize.fragment(item.link)
               end

    # remove whitespaces from beginning and end to avoid what happened with
    # iProfesional feed
    link_url = link_url.strip

    # if the URL doesn't contain it's host like this:
    # /notas/201705/187896-jorge-fernandez-diaz-miembro-academia-argentina-de-letras.html
    unless link_url.start_with?('http://', 'https://')
      link_url = "#{feed_uri.scheme}://#{feed_uri.host}/#{link_url.sub(/^\//, '')}"
    end

    # if the URL is malformed like this:
    # http://www.perfil.com/http://trends.perfil.com/2016-12-31-3981-enterate-si-esta-noche-te-quedas-sin-whatsapp/
    link_url.gsub(/^https?:\/\/.+(https?:\/\/)/, '\1')
  end

  def self.news_image_url(url)
    page = MetaInspector.new(url)

    image = page.images.best
    if NewsFetcher.matches_infobae_fallback_image(image)
      nil
    else
      image
    end
  rescue
    nil
  end

  def self.date_from_news(item)
    DateTime.parse(item.date.to_s).strftime('%s')
  rescue
    nil
  end

  def save_news_from_source(source)
    feed_uri = URI.parse(source['url'])
    open(source['url']) do |rss|
      feed = RSS::Parser.parse(rss, false)
      feed.items.each do |item|
        link_url = NewsFetcher.url_from_news(item, feed_uri)

        # fixes weird case where several news from Infobae where being
        # stored as http://xyz and https://xyz causing duplicated news
        link_to_search = link_url.gsub(/^(http|https):\/\//, '')

        if News.where('url LIKE ?', "%#{link_to_search}").exists?
          #@logger.debug("#{link_url[0...40]} is duplicated. s:#{source['source_id']}")
        else
          img_url = NewsFetcher.news_image_url(link_url)
          title = Sanitize.fragment(item.title).strip

          date = NewsFetcher.date_from_news(item)
          date = DateTime.now.strftime('%s') if date.nil?

          if NewsFetcher.matches_infobae_spam_from_other_newspapers(title) && source['name'] == 'Infobae'
            @logger.debug("Skipping #{title}")
            next
          end

          if NewsFetcher.matches_infobae_spam_currency(title) && source['name'] == 'Infobae'
            @logger.debug("Skipping #{title}")
            next
          end

          if NewsFetcher.matches_infobae_spam_coronavirus(title) && source['name'] == 'Infobae'
            @logger.debug("Skipping #{title}")
            next
          end

          if NewsFetcher.matches_infobae_posts_from_agencias(link_url) && source['name'] == 'Infobae'
            @logger.debug("Skipping #{title}")
            next
          end

          if NewsFetcher.matches_lanacion_spam_coronavirus(title) && source['name'] == 'La Nacion'
            @logger.debug("Skipping #{title}")
            next
          end

          bayes_category_id = nil
          if !@bayes_trainer.nil? && source['category_id'].nil?
            bayes_category_id = @bayes_trainer.classify_title(title)
          end

          ActiveRecord::Base.connection_pool.with_connection do
            news = News.create(
              url: link_url,
              title: title,
              date: date,
              source_id: source['source_id'],
              img_url: img_url,
              bayes_category_id: bayes_category_id
            )
            @logger.debug("Saving #{link_url}. s:#{source['source_id']}, bc: #{bayes_category_id} c: #{source['category_id']}")

            text = Highscore::Content.new news.title, @blacklist
            text.configure do
              # ignore short words such as "el", "que", "muy"
              set :short_words_threshold, 3
            end

            item_keys = text.keywords.top(5).map { |item| item.text }

            item_keys.each do |item|
              tag = Tag.where(name: item)
              unless tag.exists?
                tag = Tag.create(name: item)
              end

              news.tags << [tag]
              # @logger.debug("#{news.title} -> #{tag.take.name}")
            end
          end
          # @logger.debug("#{date} - #{title[0...40]}")
        end
      end
    end
  rescue => e
    @logger.warn("Exception: #{e.message} at #{feed_uri}")
  end

  def self.matches_infobae_spam_currency(title)
    # this matches every title with "Dólar hoy en <country>" or
    # "Euro hoy en <country>" (except Argentina)
    # commonly used on Infobae
    # https://rubular.com/r/RlNWQjoviBtLCP
    regex = /^(Dólar|Euro) hoy en (?!Argentina)/
    title.match(regex)
  end

  def self.matches_lanacion_spam_coronavirus(title)
    # this matches every title with
    # "Coronavirus en Argentina: casos en <something> al <number> de <month>"
    # https://rubular.com/r/qqRTvv8gyIG7q2
    regex = /^Coronavirus en Argentina: casos en .* al \d+ .*/i
    title.match(regex)
  end

  def self.matches_infobae_spam_from_other_newspapers(title)
    # this matches every title with "<something> xx de <month> de <year>" commonly
    # used for quoting news from other newspapers on Infobae
    regex = /.+[0-9]+\sde\s(Enero|Febrero|Marzo|Abril|Mayo|Junio|Julio|Agosto|Septiembre|Octubre|Noviembre|Diciembre)\sde\s[0-9]+/i
    title.match(regex)
  end

  def self.matches_infobae_fallback_image(url)
    regex = /.*infobae.*fallback-promo.*/
    url.match(regex)
  end

  def self.matches_infobae_spam_coronavirus(title)
    # this matches every title with
    # "<something> muertes por COVID-19 y la cifra asciende a <number>"
    # https://rubular.com/r/p57NxBYEj5vEBt
    regex = /^.*\smuertes por COVID-19 y la cifra asciende a \d*.\d*/i
    title.match(regex)
  end

  def self.matches_infobae_posts_from_agencias(url)
    # this matches every post with url that contains "america/agencias" on the URL
    # which covers lots of news that are less interesting
    url.include? "america/agencias"
  end

  def fetch_sources(sources)
    threads = []
    sources.each do |s|
      threads << Thread.new do |t|
        @logger.info("From #{s['name']} (#{s['url']})")
        save_news_from_source(s)
      end
    end

    threads.each do |t|
      t.join
    end
  end

  def fetch
    # we only fetch sources that are enabled (a.k.a "still works")
    @logger.info('START: Fetching news')
    fetcher_threads = ENV['FETCHER_THREADS'].nil? ? 20 : ENV['FETCHER_THREADS'].to_i
    Source.where('fetch_enabled = 1').each_slice(fetcher_threads) do |sources|
      fetch_sources(sources)
    end
    @logger.info('END: Fetching news')
  end
end
