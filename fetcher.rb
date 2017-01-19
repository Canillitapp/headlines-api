require 'rss'
require 'open-uri'
require 'sanitize'
require 'logger'
require 'highscore'
require 'uri'
require 'metainspector'

require './news'
require './source'

# NewsFetcher
class NewsFetcher
  def initialize
    @logger = Logger.new(STDOUT)
  end

  def save_news_from_source(source)
    feed_uri = URI.parse(source['url'])
    open(source['url']) do |rss|
      feed = RSS::Parser.parse(rss, false)
      feed.items.each do |item|
        link_url = item.link

        link_url = if link_url.is_a? RSS::Atom::Feed::Link
                     item.link.href
                   else
                     Sanitize.fragment(item.link)
                   end

        # relative paths
        link_url = "#{feed_uri.scheme}://#{feed_uri.host}/#{item.link.sub(/^\//, '')}" unless link_url.start_with?('http://', 'https://')

        # if the URL is malformed like this:
        # http://www.perfil.com/http://trends.perfil.com/2016-12-31-3981-enterate-si-esta-noche-te-quedas-sin-whatsapp/
        link_url = link_url.gsub(/^https?:\/\/.+(https?:\/\/)/, '\1')

        img_url = nil

        begin
          page = MetaInspector.new(link_url)
          img_url = page.images.best
        rescue => e
          @logger.warn("Exception: #{e.message}")
        end

        title = Sanitize.fragment(item.title).strip

        begin
          date = DateTime.parse(item.date.to_s).strftime('%s')
        rescue
          date = DateTime.now.strftime('%s')
        end

        if News.where(url: link_url).exists?
          @logger.debug("#{date} - #{title[0...40]} already exists. Stop importing from this source")
          break
        else
          ActiveRecord::Base.connection_pool.with_connection do
            News.create(
              url: link_url,
              title: title,
              date: date,
              source_id: source['source_id'],
              img_url: img_url
            )
          end
          @logger.debug("#{date} - #{title[0...40]} | img: #{img_url[0...50]}")
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

  def latest_news(date)
    date_begin = Date.strptime("#{date} -0300", '%Y-%m-%d %z')
    date_end = date_begin + 1

    News
      .where('date > ?', date_begin.to_time.to_i)
      .where('date < ?', date_end.to_time.to_i)
      .order('date DESC')
  end

  def keywords_from_news(news, count)
    tmp = ''
    news.each do |n|
      tmp << "#{n['title']}\n"
    end

    blacklist = Highscore::Blacklist.load_file 'blacklist.txt'
    text = Highscore::Content.new tmp, blacklist
    text.configure do
      # ignore short words such as "el", "que", "muy"
      set :short_words_threshold, 3
    end

    text.keywords.top(count)
  end

  def trending_news(date, count)
    latest_news = latest_news(date)
    keywords = keywords_from_news(latest_news, count * 2)

    trending = {}
    keywords.each do |k|
      trending[k.to_s] = []
    end

    latest_news.each do |i|
      keywords.each do |k|
        if i['title'].include? k.to_s
          # convert the ActiveRecord to a hash despite its confusing name
          # then add the source_name 'property'
          h = i.as_json
          h['source_name'] = i.source_name
          trending[k.to_s] << h
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
end
