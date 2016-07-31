require 'rss'
require 'open-uri'
require 'sanitize'
require 'sqlite3'
require 'logger'
require 'highscore'

# NewsFetcher
class NewsFetcher
  def initialize
    @db = SQLite3::Database.new('news.db')
    @db.results_as_hash = true
    @logger = Logger.new(STDOUT)
  end

  def save_news_from_source(source)
    open(source['url']) do |rss|
      feed = RSS::Parser.parse(rss, false)
      feed.items.each do |item|
        link_url = item.link

        link_url = if link_url.is_a? RSS::Atom::Feed::Link
                     item.link.href
                   else
                     Sanitize.fragment(item.link)
                   end

        title = Sanitize.fragment(item.title).strip

        begin
          date = DateTime.parse(item.date.to_s).strftime('%s')
        rescue
          date = DateTime.now.strftime('%s')
        end

        @db.execute(
          'INSERT INTO news(url, title, date, source_id) VALUES(?, ?, ?, ?)',
          link_url,
          title,
          date,
          source['source_id'])
        @logger.debug("#{date} - #{title[0...50]}")
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

  def daily_trending_keywords
    tmp = ''
    @db.execute('SELECT title, news.url, sources.name, '\
      'strftime(\'%s\',\'now\') - news.date as time_diff FROM news '\
      'JOIN sources ON news.source_id = sources.source_id '\
      'WHERE language LIKE "es" AND time_diff < 86400').each do |n|
      tmp << "#{n['title']}\n"
    end
    blacklist = Highscore::Blacklist.load_file 'blacklist.txt'
    text = Highscore::Content.new tmp, blacklist
    text.configure do
      set :short_words_threshold, 3
    end

    text.keywords.top(3)
  end

  def daily_trending_news
    desired_keys = ['title', 'url', 'date', 'source_name']
    news = {}
    keywords = daily_trending_keywords
    keywords.each do |keyword|
      tmp = @db.execute('SELECT title, news.url, news.date, sources.name as '\
        'source_name, strftime(\'%s\',\'now\') - news.date as time_diff '\
        'FROM news '\
        'JOIN sources ON news.source_id = sources.source_id '\
        "WHERE title LIKE \'%#{keyword}%\' AND time_diff < 86400 "\
        'ORDER BY news.date DESC')
      tmp.each do |item|
        item.delete_if { |key, _value| !desired_keys.include? key }
      end
      news[keyword] = tmp
    end
    { 'keywords' => keywords, 'news' => news }
  end
end
