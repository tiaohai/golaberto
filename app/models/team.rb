class Team < ActiveRecord::Base
  has_many :team_groups
  has_many :groups,      :through     => :team_groups
  has_many :home_games,  :foreign_key => "home_id",    :class_name => "Game"
  has_many :away_games,  :foreign_key => "away_id",    :class_name => "Game"

  # Fields information, just FYI.
  #
  # Field: id , SQL Definition:bigint(20)
  # Field: name , SQL Definition:varchar(255)
  # Field: country , SQL Definition:varchar(255)
  # Field: logo , SQL Definition:varchar(255)
  
  def next_n_games(n, phase = nil)
    cond = "played = 'scheduled'"
    cond += " AND phase_id = #{phase}" unless phase.nil?
    ret = n_games(n, cond, "ASC").sort do |a,b|
      a.date <=> b.date
    end
    ret.slice(0..4)
  end

  def last_n_games(n, phase = nil)
    cond = "played = 'played'"
    cond += " AND phase_id = #{phase}" unless phase.nil?
    ret = n_games(n, cond, "DESC").sort do |a,b|
      b.date <=> a.date
    end
    ret.slice(0..4)
  end

  private
  def n_games(n, condition, order)
    home = self.home_games.find(
        :all,
        :order => "date #{order}",
        :conditions => condition,
        :limit => n)
    away = self.away_games.find(
        :all,
        :order => "date #{order}",
        :conditions => condition,
        :limit => n)

    home + away
  end

end
