require 'date'
require 'logger'

require './database'
require './content_view'
require './interaction'
require './interest'
require './reaction'
require './tag'
require './user'

class InterestsReportMaker

  def initialize
    @logger = Logger.new(STDOUT)
  end

  def report_from_user(user_id)
    interactions = []

    # getting all content_views tags
    content_views = ContentView
                      .select('news_id, date')
                      .where('user_id = ?', user_id)

    content_views.each do |c|
      tags = Tag
              .joins(:news)
              .where('news_tags.news_id = ?', c.news_id)
              .where('tags.blacklisted = 0')

      # tags is a ActiveRecord::Relation, I'm interested on getting all the objects
      # from that relation (Tag objects) using to_a.
      tags.to_a.each do |t|
        i = Interaction.new(
          tag_id: t.tag_id,
          tag_name: t.name,
          date: c.date,
          is_reaction: false
        )
        interactions << i
      end
    end

    # getting all reaction tags
    reactions = Reaction
                  .select('news_id, date')
                  .where('user_id = ?', user_id)

    reactions.each do |r|
      tags = Tag
              .joins(:news)
              .where('news_tags.news_id = ?', r.news_id)
              .where('tags.blacklisted = 0')

      # tags is a ActiveRecord::Relation, I'm interested on getting all the objects
      # from that relation (Tag objects) using to_a.
      tags.to_a.each do |t|
        i = Interaction.new(
          tag_id: t.tag_id,
          tag_name: t.name,
          date: Time.at(r.date),
          is_reaction: true
        )
        interactions << i
      end
    end

    group = interactions.group_by { |i| i.tag_name }

    interests = []
    group.each do |k, v|
      i = {
        score: v.inject(0) { |sum, x| sum + x.score },
        tag_id: v.first.tag_id,
        tag_name: v.first.tag_name
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
