require './database'
require './tag'
require './user'

class Interest < ActiveRecord::Base
  belongs_to :user
  belongs_to :tag

  def self.from_user(user_id)
    Interest
      .select('interest_id, interests.tag_id, score, tags.name as name')
      .joins(:tag)
      .where('user_id = ?', user_id)
      .where('tags.blacklisted = 0')
      .order(score: :desc)
      .limit(20)
  end

end
