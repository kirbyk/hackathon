class TeamsController < ApplicationController
  before_action :set_team, only: [:edit, :update, :destroy]
  helper_method :hacker_full_name, :hacker_email, :hacker_school, :remove_hacker
  skip_before_action :require_login, only: [:join]
  load_and_authorize_resource

  # GET /teams
  # GET /teams.json
  def index
    @teams = Team.all
  end

  # GET /teams/1
  # GET /teams/1.json
  def show
    if current_user.team_id.nil?
      redirect_to dashboard_url
    else
      @team = Team.find(current_user.team_id)
      teammates = @team.hackers.reject{ |h| h == current_user }
      @current_name = current_user.full_name.present? ? current_user.full_name : 'Me'
      @others = []
      3.times do |i|
        teammate = teammates[i]
        if teammate.present?
          name = teammate.full_name.present? ? teammate.full_name : 'Friend'
          @others << {name: name, present: true, email: teammate.email}
        else
          @others << {name: 'Teammate', present: false}
        end
      end
    end
  end

  # GET /teams/new
  def new
    @team = Team.new

    respond_to do |format|
      if @team.save
        format.html { redirect_to my_team_path, notice: 'Team was successfully created.' }
        format.json { render :show, status: :created, location: @team }
      else
        format.html { render :new }
        format.json { render json: @team.errors, status: :unprocessable_entity }
      end
    end

    add_hacker(@team, current_user)
  end

  # GET /teams/1/edit
  def edit
  end

  # POST /teams
  # POST /teams.json
  def create
    @team = Team.new(team_params)

    respond_to do |format|
      if @team.save
        format.html { redirect_to @team, notice: 'Team created successfully.' }
        format.json { render :my_team, status: :created, location: @team }
      else
        format.html { render :new }
        format.json { render json: @team.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /teams/1
  # PATCH/PUT /teams/1.json
  def update
    respond_to do |format|
      if @team.update(team_params)
        format.html { redirect_to @team, notice: 'Team was successfully updated.' }
        format.json { render :show, status: :ok, location: @team }
      else
        format.html { render :edit }
        format.json { render json: @team.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /teams/1
  # DELETE /teams/1.json
  def destroy
    @team.destroy
    respond_to do |format|
      format.html { redirect_to teams_url, notice: 'Team was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def leave
    current_user.team_id = nil
    if current_user.save
      flash[:success] = "You are no longer on any team"
    else
      flash[:alert] = 'Something went wrong, you have not left your team'
    end
    redirect_to dashboard_url
  end

  def join
    # if user is not logged in
    # the flashes get lost in the redirect through the dashboard
    if current_user.nil?
      redirect_to root_url, alert: 'Please login or create an account first'
    else
      if current_user.team_id.present?
        redirect_to dashboard_url, alert: 'You need to leave your current team before joining a new one'
      else
        @team = Team.find_by_secret_key(params[:secret_key])
        if @team
          if @team.hackers.count >= 4
            flash[:alert] = 'Team is currently full'
          else
            current_user.team_id = @team.id
            if current_user.save
              flash[:success] = "You've joined a team!"
            else
              flash[:alert] = 'Could not join this team'
            end
          end
          redirect_to dashboard_url
        else
          redirect_to dashboard_url, alert: 'Invalid team key'
        end
      end
    end
  end

  def remove_hacker
    @team = Team.find(params[:id])
    @user = current_user
    @team.hackers.delete(@user)
    redirect_to dashboard_url
  end

  def add_hacker(team, hacker)
    hacker.update(team_id: team.id)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_team
      @team = Team.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def team_params
      params[:team]
    end
end
