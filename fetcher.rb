require 'rss'
require 'open-uri'
require 'sanitize'
require 'logger'
require 'highscore'
require 'uri'
require 'metainspector'
require 'i18n'

require './news'
require './source'

# NewsFetcher
class NewsFetcher
  def initialize
    @logger = Logger.new(STDOUT)
    @blacklist = Highscore::Blacklist.load_file 'blacklist.txt'
  end

  def self.url_from_news(item, feed_uri)
    link_url = if item.link.is_a? RSS::Atom::Feed::Link
                 item.link.href
               else
                 Sanitize.fragment(item.link)
               end

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
    page.images.best
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
          @logger.debug("#{link_url[0...40]} is duplicated. s:#{source['source_id']}")
        else
          img_url = NewsFetcher.news_image_url(link_url)
          title = Sanitize.fragment(item.title).strip

          date = NewsFetcher.date_from_news(item)
          date = DateTime.now.strftime('%s') if date.nil?

          ActiveRecord::Base.connection_pool.with_connection do
            news = News.create(
              url: link_url,
              title: title,
              date: date,
              source_id: source['source_id'],
              img_url: img_url
            )
            @logger.debug("Saving #{link_url[0...40]}. s:#{source['source_id']}")

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
    @logger.warn("Exception: #{e.message}")
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
    @logger.info('Fetching news')
    Source.all.each_slice(3) do |sources|
      fetch_sources(sources)
    end
  end
end
