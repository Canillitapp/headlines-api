class Interaction
  attr_accessor :tag_id, :tag_name
  attr_reader :score

  def initialize(args)
    @tag_id = args[:tag_id] if args[:tag_id]
    @tag_name = args[:tag_name] if args[:tag_name]

    # some old entries have NULL date so we're using Time.now as default
    date = args[:date] || Time.now
    is_reaction = args[:is_reaction] if args[:is_reaction]
    @score = Interaction.score_from_date(date, is_reaction)
  end

  def self.score_from_date(date, is_reaction)
    difference_days = (Time.now - date).to_i / 1.day

    s = case difference_days
        when 0..15
          100
        when 16..30
          50
        when 31..120
          25
        else
          10
        end

    # reactions are twice important as content_views
    s *= 2 if is_reaction
    s
  end
end
