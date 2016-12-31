require 'rss'
require 'open-uri'
require 'sanitize'
require 'sqlite3'
require 'logger'
require 'highscore'
require 'uri'
require 'metainspector'

# NewsFetcher
class NewsFetcher
  def initialize
    @db = SQLite3::Database.new('news.db')
    @db.results_as_hash = true
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

        @db.execute(
          'INSERT INTO news(url, title, date, source_id, img_url) '\
          'VALUES(?, ?, ?, ?, ?)',
          link_url,
          title,
          date,
          source['source_id'],
          img_url
        )
        @logger.debug("#{date} - #{title[0...40]} | img: #{img_url[0...50]}")
      end
    end
  rescue => e
    @logger.warn("Exception: #{e.message}")
  end

  def fetch
    @logger.info('Fetching news')

    @db.execute('SELECT * FROM sources').each do |s|
      @logger.info("From #{s['name']} (#{s['url']})")
      save_news_from_source(s)
    end
  end

  def latest_news(date)
    desired_keys = ['title', 'url', 'date', 'source_name', 'img_url']
    news = @db.execute('SELECT title, news.url, news.date, sources.name as '\
      "source_name, news.date - strftime(\'%s\',\'#{date}\') as time_diff, "\
      'img_url '\
      'FROM news '\
      'JOIN sources ON news.source_id = sources.source_id '\
      'WHERE time_diff < 86400 AND time_diff >= 0 '\
      'ORDER BY news.date DESC')
    news.each do |item|
      item.delete_if { |key, _value| !desired_keys.include? key }
    end
    news
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
end
