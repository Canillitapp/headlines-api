require File.expand_path(File.dirname(__FILE__) + '/../trending_topic_push.rb')

date = Time.now.strftime('%Y-%m-%d')
push_trending_news(date)
