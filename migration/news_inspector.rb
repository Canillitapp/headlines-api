require 'rss'
require 'open-uri'
require 'sanitize'
require 'logger'
require 'logger/colors'
require 'uri'
require 'metainspector'
require 'i18n'
require 'yaml'

require File.expand_path(File.dirname(__FILE__) + '/../source.rb')

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

  def self.date_from_news(item)
    DateTime.parse(item.date.to_s).strftime('%s')
  rescue
    nil
  end

  def meta_from_url(url)
    meta = {}
    page = MetaInspector.new(url, :connection_timeout => 10, :read_timeout => 5)
    meta['image_url'] = page.images.best
    meta['keywords'] = page.meta_tag['name']['keywords'].split(',')
    meta
  rescue => e
    @logger.error("Exception @ MetaInspector: #{e.message}")
    meta
  end

  def news_from_source(source)
    feed_uri = URI.parse(source['url'])
    open(source['url']) do |rss|
      feed = RSS::Parser.parse(rss, false)
      feed.items.each do |item|
        link_url = NewsFetcher.url_from_news(item, feed_uri)
        title = Sanitize.fragment(item.title).strip
        
        @logger.info(link_url)
        @logger.debug(title)

        rss_image = nil
        unless item.enclosure.nil?
          rss_image = item.enclosure.url
          @logger.debug("- Image (RSS): #{rss_image}")
        end

        meta = meta_from_url(link_url)
        
        @logger.debug("- Image (meta): #{meta['image_url']}")
        @logger.debug("- Keywords: #{meta['keywords']}")

        open('news_inspection.txt', 'a') { |f| 
          f.puts title
          f.puts link_url
          
          unless rss_image.nil?
            f.puts "- Image (RSS): #{rss_image}"
          end

          f.puts "- Image (meta): #{meta['image_url']}"
          f.puts "- Keywords: #{meta['keywords']}" 
          f.puts "---\n\n"
        }
      end
    end
  rescue => e
    @logger.warn("Exception: #{e.message}")
  end

  def fetch
    @logger.info('Fetching news')

    Source.all.each do |s|
      if s['meta_tags_enabled'] == nil
        @logger.info("Skipping #{s['name']} (#{s['url']})")
        next
      end

      @logger.info("From #{s['name']} (#{s['url']})")
      news_from_source(s)
    end
  end
end

news = NewsFetcher.new
news.fetch
