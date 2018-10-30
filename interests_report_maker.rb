require 'logger'

require './database'
require './content_view'
require './interest'
require './reaction'
require './tag'
require './user'

class InterestsReportMaker

  def initialize
    @logger = Logger.new(STDOUT)
  end

  def report_from_user(user_id)
    tags = []

    # getting all content_views tags
    content_views = ContentView
                      .select('news_id')
                      .where('user_id = ?', user_id)

    content_views.each do |c|
      t = Tag
            .joins(:news)
            .where('news_tags.news_id = ?', c.news_id)
            .where('tags.blacklisted = 0')

      # t is a ActiveRecord::Relation, I'm interested on getting all the objects
      # from that relation (Tag objects).
      tags.concat(t.to_a)
    end

    # getting all reaction tags
    reactions = Reaction
                  .select('news_id')
                  .where('user_id = ?', user_id)

    reactions.each do |r|
      t = Tag
            .joins(:news)
            .where('news_tags.news_id = ?', r.news_id)
            .where('tags.blacklisted = 0')

      # t is a ActiveRecord::Relation, I'm interested on getting all the objects
      # from that relation (Tag objects).
      tags.concat(t.to_a)
    end

    group = tags.group_by { |i| i.name }

    # in case you want to return tags sorted alphabetically...
    # group.select { |k, v| v.count > 1 }
    # group.sort_by { |k, v| k.downcase.parameterize }

    # group.each { |k, v| group[k] = v.count }
    group = group.sort_by { |k, v| v.count }.reverse

    interests = []
    group.each do |k, v|
      i = {
        score: v.count,
        tag_id: v.first.tag_id,
        tag_name: v.first.name
      }
      interests << i
    end

    interests
  end

  def update_report_from_user(user_id)
    interests = report_from_user(user_id)
    interests.each do |item|
      i = Interest.find_by(user_id: user_id, tag_id: item[:tag_id])

      if i.nil?
        i = Interest.new
        i.user_id = user_id
        i.tag_id = item[:tag_id]
      end

      i.score = item[:score]
      i.last_update = Time.now.getutc
      i.save
    end

    u = User.find_by(user_id: user_id)
    u.last_report_date = Time.now.getutc
    u.save
  end

  def update_reports
    users = User
      .select(:user_id)
      .where('last_report_date < ?', 1.day.ago)
      .group(:user_id, :last_report_date)
      .order(:last_report_date)
      .limit(100)

    users.each do |u|
      @logger.debug("Updating #{u.user_id}")
      update_report_from_user(u.user_id)
    end
  end

end
