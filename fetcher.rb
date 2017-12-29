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
    blacklist = Highscore::Blacklist.load_file 'blacklist.txt'

    feed_uri = URI.parse(source['url'])
    open(source['url']) do |rss|
      feed = RSS::Parser.parse(rss, false)
      feed.items.each do |item|
        link_url = NewsFetcher.url_from_news(item, feed_uri)

        if News.where(url: link_url).exists?
          # @logger.debug("#{link_url[0...40]} already exists. Stop importing from this source")
          break
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

            text = Highscore::Content.new news.title, blacklist
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

  def fetch
    @logger.info('Fetching news')

    Source.all.each do |s|
      @logger.info("From #{s['name']} (#{s['url']})")
      save_news_from_source(s)
    end
  end

  def latest_news_with_reactions(date)
    News.from_date(date).map do |i|
      # convert the ActiveRecord to a hash despite its confusing name
      # then add the source_name 'property'
      tmp = i.as_json
      tmp['source_name'] = i.source_name
      tmp['reactions'] = Reaction.raw_reactions_by_news_id(i.news_id)
      tmp
    end
  end

  def trending_news(date, count)
    latest_news = latest_news_with_reactions(date)
    keywords = Tag.keywords_from_date(date, count * 2).map { |item| item.name }

    trending = {}
    keywords.each do |k|
      trending[k.to_s] = []
    end

    latest_news.each do |i|
      keywords.each do |k|
        if I18n.transliterate(i['title']).include? k.to_s
          trending[k.to_s] << i
          break
        end
      end
    end

    ordered_keywords = keywords.sort do |x, y|
      trending[y.to_s].length <=> trending[x.to_s].length
    end

    ordered_keywords = ordered_keywords.take(count).map(&:to_s)

    trending = trending.select do |k, _|
      ordered_keywords.include? k.to_s
    end

    { 'keywords' => ordered_keywords, 'news' => trending }
  end

  def popular_news
    News.popular_news.map do |i|
      # convert the ActiveRecord to a hash despite its confusing name
      # then add the source_name 'property'
      tmp = i.as_json
      tmp['source_name'] = i.source_name
      tmp['reactions'] = Reaction.raw_reactions_by_news_id(i.news_id)
      tmp
    end
  end
end
