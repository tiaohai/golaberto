class Team < ActiveRecord::Base
  require 'RMagick'
  include Magick

  has_many :team_groups, :dependent => :delete_all
  has_many :groups, :through => :team_groups
  has_many :home_games, :foreign_key => "home_id", :class_name => "Game", :dependent => :destroy
  has_many :away_games, :foreign_key => "away_id", :class_name => "Game", :dependent => :destroy
  has_many :team_players, :dependent => :delete_all, :include => :player
  validates_length_of :name, :within => 1..40
  validates_uniqueness_of :name, :message => "already exists"

  # Fields information, just FYI.
  #
  # Field: id , SQL Definition:bigint(20)
  # Field: name , SQL Definition:varchar(255)
  # Field: country , SQL Definition:varchar(255)
  # Field: logo , SQL Definition:varchar(255)
  
  def uploaded_logo=(l)
    image = ImageList.new.from_blob(l.read)
    image.change_geometry("100x100") do |cols, rows, img|
      img.resize!(cols, rows)
    end
    background = ImageList.new("#{RAILS_ROOT}/public/images/logos/100.png")
    image = background.composite(image, CenterGravity, OverCompositeOp) 
    image.write("#{RAILS_ROOT}/public/images/logos/#{self.id}_100.png")
    image.scale!(15, 15)
    image.write("#{RAILS_ROOT}/public/images/logos/#{self.id}_15.png")
    self.logo = "#{self.id}.svg"
    save!
  end

  def small_logo
    if logo.nil?
      '15.png'
    else
      logo.gsub(/(.*)\.svg/, '\1_15.png')
    end
  end

  def large_logo
    if logo.nil?
      '100.png'
    else
      logo.gsub(/(.*)\.svg/, '\1_100.png')
    end
  end
  
  def next_n_games(n, phase = nil)
    cond = [ "played = ?", false ]
    if phase.nil?
      cond[0] << " AND championships.category_id = ?";
      cond << Category::DEFAULT_CATEGORY
    else
      cond[0] << " AND phase_id = ?"
      cond << phase.id
    end
    ret = n_games(n, cond, "ASC").sort do |a,b|
      a.date <=> b.date
    end
    ret.slice(0..4)
  end

  def last_n_games(n, phase = nil)
    cond = [ "played = ?", true ]
    if phase.nil?
      cond[0] << " AND championships.category_id = ?";
      cond << Category::DEFAULT_CATEGORY
    else
      cond[0] << " AND phase_id = ?"
      cond << phase.id
    end
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
        :include => [ { :phase => :championship } ],
        :limit => n)
    away = self.away_games.find(
        :all,
        :order => "date #{order}",
        :conditions => condition,
        :include => [ { :phase => :championship } ],
        :limit => n)

    home + away
  end

end
