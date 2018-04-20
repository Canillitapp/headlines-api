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
    @logger.level = Logger::WARN #Logger::INFO
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

  def meta_from_url(url)
    meta = {}
    page = MetaInspector.new(url, :connection_timeout => 10, :read_timeout => 5)
    meta['image_url'] = page.images.best
    meta['keywords'] = page.meta_tag['name']['keywords'].split(',').map { |i| i.lstrip }
    meta
  rescue => e
    @logger.error("Exception @ MetaInspector: #{e.message}")
    meta
  end

  def save_keywords(news, keywords, is_from_meta)
    keywords.each do |item|
      Tag.where(name: item).first_or_create do |tag|
        NewsTag.create(
          news: news,
          tag: tag,
          is_from_meta: is_from_meta
        )
      end
    end
  end

  def save_highscore_keywords(news)
    blacklist = Highscore::Blacklist.load_file 'blacklist.txt'

    text = Highscore::Content.new news.title, blacklist
    text.configure do
      # ignore short words such as "el", "que", "muy"
      set :short_words_threshold, 3
    end

    item_keys = text.keywords.top(5).map { |item| item.text }
    @logger.debug("Saving keywords (Highscore): #{item_keys}")
    save_keywords(news, item_keys, false)
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
          @logger.debug("#{link_url[0...40]} is duplicated")
        else
          title = Sanitize.fragment(item.title).strip

          # meta: will be used on image and extra keywords
          # (if source has meta_tags_enabled)
          meta = meta_from_url(link_url)

          # date
          date = NewsFetcher.date_from_news(item)
          date = DateTime.now.strftime('%s') if date.nil?

          # image
          image = meta['image_url']
          if image.nil? && !item.enclosure.nil? && !item.enclosure.url.nil?
            image = item.enclosure.url
            @logger.debug("RSS image: #{image}")
          end

          ActiveRecord::Base.connection_pool.with_connection do
            news = News.create(
              url: link_url,
              title: title,
              date: date,
              source_id: source['source_id'],
              img_url: image
            )
            @logger.info("Saving #{link_url}")
            @logger.info(title)

            save_highscore_keywords(news)

            if source['meta_tags_enabled'].nil? || meta['keywords'].nil?
              @logger.debug('Skipping meta tags')
            else
              @logger.debug("Saving keywords (meta): #{meta['keywords']}")
              save_keywords(news, meta['keywords'], true)
            end
          end
        end
      end
    end
  rescue => e
    @logger.warn("Exception: #{e.message}")
  end

  def fetch
    @logger.info('Fetching news')

    Source.all.each do |s|
      @logger.info("From #{s['name']} (#{s['url']})")
      save_news_from_source(s)
    end
  end

  def trending_news(date, count)
    latest_news = News
                      .from_date(date)
                      .map { |i| News.add_reactions_to_news(i) }
    keywords = Tag.keywords_from_date(date, count * 2).map { |item| item.name }

    trending = {}
    keywords.each do |k|
      trending[k.to_s] = []
    end

    latest_news.each do |i|
      keywords.each do |k|
        key = I18n.transliterate(k.to_s).downcase
        title = I18n.transliterate(i['title']).downcase
        if title.include? key
          trending[k.to_s] << i
          break
        end
      end
    end

    ordered_keywords = keywords.sort do |x, y|
      trending[y.to_s].length <=> trending[x.to_s].length
    end

    # ignore keywords that doesn't contain a news
    ordered_keywords = ordered_keywords.select { |k| trending[k].length > 0 }

    # take 'count' keywords
    ordered_keywords = ordered_keywords.take(count).map(&:to_s)

    trending = trending.select do |k, _|
      ordered_keywords.include? k.to_s
    end

    { 'keywords' => ordered_keywords, 'news' => trending }
  end
end
