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
          # @logger.debug("#{link_url[0...40]} is duplicated")
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
            # @logger.debug("Saving #{link_url[0...40]}")

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

  def fetch
    @logger.info('Fetching news')

    Source.all.each do |s|
      @logger.info("From #{s['name']} (#{s['url']})")
      save_news_from_source(s)
    end
  end

  def trending_news(date, count)
    keywords = Tag.keywords_from_date(date, count * 3)

    date_begin = Date.strptime("#{date} -0300", '%Y-%m-%d %z')
    date_end = date_begin + 1

    keywords_ids = keywords.map { |i| i.tag_id }
    keywords_names = keywords.map { |i| i.name }

    news = News
           .select('news.*, tags.tag_id, tags.name')
           .joins(:tags)
           .where('date > ?', date_begin.to_time.to_i)
           .where('date < ?', date_end.to_time.to_i)
           .where('news_tags.tag_id' => keywords_ids)
           .order('date DESC')

    trending = {}
    keywords_names.each do |k|
      trending[k.to_s] = []
    end

    news.each do |i|
      keywords_names.each do |k|
        # remove any kind of punctuation on title so it's possible to match
        # "tarifa," with keyword "tarifa"
        if i.title.gsub(/[^[:word:]\s]/, '').split(' ').include? k
          trending[k.to_s] << i
        end
      end
    end

    # remove duplicate news
    trending.each_value { |v| v.uniq! }

    # sort keywords (first has more items)
    ordered_keywords = keywords_names.sort do |x, y|
      trending[y.to_s].length <=> trending[x.to_s].length
    end

    # remove elements that are in more than one trending item
    ordered_keywords.each do |k1|
      trending[k1].each do |v1|
        ordered_keywords.each do |k2|
          next if k1 == k2
          trending[k2].delete_if { |v2| v1.news_id == v2.news_id }
        end
      end
    end

    # sort keywords again (first has more items)
    ordered_keywords = keywords_names.sort do |x, y|
      trending[y.to_s].length <=> trending[x.to_s].length
    end

    # debug
    # ordered_keywords.each { |k| @logger.debug "#{k} (#{trending[k].length})" }

    # take 'count' keywords
    ordered_keywords = ordered_keywords.take(count).map(&:to_s)

    # ignore keywords that doesn't contain a news
    ordered_keywords = ordered_keywords.select { |k| trending[k].length > 0 }

    trending = trending.select do |k, _|
      ordered_keywords.include? k.to_s
    end

    # add reactions and source_name to every news
    trending.each do |k, v|
      trending[k] = v.map { |i| News.add_reactions_to_news(i) }
    end

    { 'keywords' => ordered_keywords, 'news' => trending }
  end
end
