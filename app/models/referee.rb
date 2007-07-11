class Referee < ActiveRecord::Base
  has_many :games, :dependent => :nullify
  validates_presence_of :name
  validates_uniqueness_of :name

  # Fields information, just FYI.
  #
  # Field: id , SQL Definition:bigint(20)
  # Field: name , SQL Definition:varchar(255)
  # Field: location , SQL Definition:varchar(255)


end
