require 'apnotic'
require './news'
require './user'

def news_to_broadcast(date)
  trending = News.trending(date, 3)
  keyword = trending['keywords'].sample

  return if keyword.nil?

  trending['news'][keyword].first
end

def notification_from_news_item(item, token)
  notification = Apnotic::Notification.new(token)
  notification.alert = {
    'title' => item['source_name'],
    'body' => item['title']
  }
  notification.mutable_content = true
  notification.category = 'news_apn'
  notification.sound = 'default'
  notification.topic = 'ar.com.betzerra.headlines'
  notification.custom_payload = {
    'media-url' => item['img_url'],
    'post-id' => item['news_id'],
    'post-url' => item['url']
  }
  notification
end

def apns_connection
  # for production pushes use:
  # https://api.push.apple.com:443
  # https://api.development.push.apple.com:443

  #Apnotic::Connection.new(
  #  cert_path: 'apns_development.pem',
  #  url: 'https://api.development.push.apple.com:443'
  #)

  Apnotic::Connection.new(
    cert_path: 'apns_development_production.pem'
  )

  #Apnotic::Connection.new(
  #  auth_method: :token,
  #  cert_path: "AuthKey_VU6355SQLQ.p8",
  #  key_id: "VU6355SQLQ",
  #  team_id: "2334RGUT2P"
  #)
end

def single_sync_push_to_token(connection, notification)
  connection.push(notification)
  # do something with "response"... I guess?
end

def single_async_push_to_token(connection, notification)
  push = connection.prepare_push(notification)
  push.on(:response) do |response|
    # do something... I guess?
    #puts response.ok?
    #puts response.status
    #puts response.body
  end
  connection.push_async(push)
end

def push_trending_news(date)
  connection = apns_connection

  item = news_to_broadcast(date)

  User.where('source = "iOS" AND device_token IS NOT NULL').each do |u|
    notification = notification_from_news_item(item, u.device_token)
    single_async_push_to_token(connection, notification)
  end

  # wait for all requests to be completed
  connection.join

  connection.close
end

#date = Time.now.strftime('%Y-%m-%d')
#push_trending_news(date)
