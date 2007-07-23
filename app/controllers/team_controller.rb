class TeamController < ApplicationController
  before_filter :login_required, :except => [ :index, :list, :show ]

  def index
    redirect_to :action => :list
  end

  def show
    @team = Team.find(params["id"])
  end

  def edit
    @team = Team.find(params["id"])
  end

  def update
    @team = Team.find(params["id"])
    @team.attributes = params["team"]

    if @team.save
      redirect_to :action => :show, :id => @team
    else
      render :action => :edit
    end
  end

  def list
    items_per_page = 10
    conditions = ["name LIKE ?", "%#{params[:id]}%"] unless params[:id].nil?

    @total = Team.count :conditions => conditions
    @team_pages, @teams = paginate :teams, :order => "name",
                                   :conditions => conditions,
                                   :per_page => items_per_page

    if request.xhr?
      render :partial => "team_list", :layout => false
    end
  end

  def new
    @team = Team.new
  end

  def create
    @team = Team.new(params[:team])
    if @team.save
      redirect_to :action => :show, :id => @team
    else
      render :action => :new
    end
  end

  def destroy
    team = Team.find(params[:id]).destroy
    redirect_to :back
  end

  def auto_complete_for_team_name
    search = params[:team][:name]
    @teams = Team.find(
        :all,
        :conditions => "name like '#{search}%'",
        :order => "name",
        :limit => 5) unless search.blank?
    render :partial => "search" 
  end
end
