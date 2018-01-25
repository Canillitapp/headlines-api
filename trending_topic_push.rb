require 'apnotic'
require './fetcher'

# for production pushes use:
# https://api.push.apple.com:443

def push_trending_news(date)
  connection = Apnotic::Connection.new(
    cert_path: "apns_development.pem",
    url: "https://api.development.push.apple.com:443"
  )

  news = NewsFetcher.new
  trending = news.trending_news(date, 1)
  keyword = trending['keywords'].first

  return if keyword.nil?

  item = trending['news'][keyword].first

  # create a notification for a specific device token
  # "aa50ff35cf419e467d6f12408587531e8878ba246ed47909d630d9f90af2d0f3"
  # "032101db30b0e4e2258e17cb9b0d551e52cd253386c20bb208166507ecda6b61"
  token = "032101db30b0e4e2258e17cb9b0d551e52cd253386c20bb208166507ecda6b61"

  notification = Apnotic::Notification.new(token)
  notification.alert = {
    "title" => item['source_name'],
    "body" => item['title']
  }
  notification.mutable_content = true
  notification.category = "news_apn"
  notification.custom_payload = {
    "media-url" => item['img_url'],
    "post-id" => item['news_id']
  }

  # send (this is a blocking call)
  response = connection.push(notification)

  # close the connection
  connection.close
end

date = Time.now.strftime('%Y-%m-%d')
push_trending_news('2018-01-01')
