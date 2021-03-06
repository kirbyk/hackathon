class HackersController < ApplicationController
  before_filter :set_genders, :downcase_email, :set_shirts, :set_races,
                :set_ethnicities, :set_job_interests, :set_job_dates,
                :set_transportation_methods
  before_action :set_hacker, only: [:update, :destroy]
  before_filter :authenticate, only: [:update, :destroy, :dashboard, :passbook]
  skip_before_action :require_login

  load_and_authorize_resource

  # GET /users
  # GET /users.json
  def index
    @hackers = Hacker.started_applicants.paginate(:page => params[:page])
    @hackers.each do |hacker|
      hacker.class_eval do
        attr_accessor :have_i_ranked
        attr_accessor :should_i_rank
      end
    end
    @hackers.each do |hacker|
      have_ranked = (HackerRanking.where(exec: current_user).where(hacker: hacker).count ==1)
      hacker.have_i_ranked = have_ranked
      hacker.should_i_rank = (!have_ranked && hacker.hacker_ranking.count<3 && hacker.application_completed?)
    end
  end

  # GET /users/1
  # GET /users/1.json
  def show
    @hacker
  end

  def dashboard
    @schools = School.all
    @hacker ||= current_user
    @application = @hacker.application
    @application ||= @hacker.build_application
    @school = @hacker.school.name if @hacker.school

    if @application.resume.present?
      @resume_button_text ='Already Uploaded! '
      @resume_div_style = ''
      @file_field_style = 'display:none;'
    else
      @resume_button_text = 'Success'
      @resume_div_style = 'display:none;'
      @file_field_style = ''
    end
  end

  # GET /users/new
  def new
    @hacker = Hacker.new
    @schools = School.all
    @applying = true
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  # POST /users.json
  def create
    @hacker = Hacker.new hacker_params

    respond_to do |format|
      if @hacker.save

        # mimics sessions/create
        user = User.find(@hacker.id)
        cookies[:auth_token] = user.auth_token

        UserMailer.welcome_email(@hacker).deliver

        if session[:return_to].present?
          format.html { redirect_to session[:return_to], notice: 'Account created successfully.' }
        else
          format.html { redirect_to :dashboard, notice: 'Account created successfully.' }
        end

        format.json { render :show, status: :created, location: @hacker }
      else
        if @hacker.errors[:email].present?
          flash[:alert] = "#{@hacker.email} #{@hacker.errors[:email][0]}"
        elsif @hacker.errors[:password_confirmation].present?
          flash[:alert] = "Your passwords don't match."
        else
          flash[:alert] = "Some error occured. Email support@boilermake.org."
        end
        format.html { redirect_to root_path(should_skip_intro: true) }
        format.json { render json: @hacker.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /users/1
  # PATCH/PUT /users/1.json
  def update
    new_params = hacker_params
    if hacker_params[:school_id].present?
      school = School.find_by(name: hacker_params[:school_id])
      if school
        school_id = School.find_by(name: hacker_params[:school_id]).id
        new_params[:school_id] = school_id
      else
        new_params[:school_id] = -1 # this won't update
      end
    else
      new_params[:school_id] = nil
    end

    okay = true
    if params["hacker"]["confirmed"]
      if current_user.accepted? \
          && params["hacker"]["transportation_method"].present?
        okay = true
      else
        okay = false
      end
    end

    respond_to do |format|
      if okay && @hacker.update(new_params) && new_params[:school_id] != -1
        flash[:success] = "Your application has been updated."
        format.html { redirect_to :dashboard }
        format.json { render :show, status: :ok, location: @hacker }
      else
        flash[:alert] = "That school doesn't exist. Email team@boilermake.org." if new_params[:school_id] == -1
        flash[:alert] = "Please fill everything out" if !okay
        format.html { redirect_to :dashboard }
        format.json { render json: @hacker.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @hacker.destroy
    respond_to do |format|
      format.html { redirect_to hackers_url, notice: 'Hacker was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def passbook
    json_data = JSON.parse(IO.read(Rails.root.join('passbook', 'data', 'pass.json')))
    json_data['barcode']['message'] = current_user.email
    json_data['eventTicket']['auxiliaryFields'][0]['value'] = current_user.full_name

    pass = Passbook::PKPass.new json_data.to_json

    pass.addFiles [ Rails.root.join('passbook', 'data', 'background.png'),
                    Rails.root.join('passbook', 'data', 'icon@2x.png'),
                    Rails.root.join('passbook', 'data', 'icon.png'),
                    Rails.root.join('passbook', 'data', 'logo.png'),
                    Rails.root.join('passbook', 'data', 'logo_web.png') ]

    pkpass = pass.stream
    send_data pkpass.string, type: 'application/vnd.apple.pkpass', disposition: 'attachment', filename: "pass.pkpass"
  end

  def confirm
    if current_user.accepted? \
       && current_user.extra_fields_completed? \
       && current_user.application_completed?
      current_user.update(confirmed: true)
      redirect_to dashboard_path
    elsif current_user.accepted?
      redirect_to dashboard_path, flash: { notice: "Please fill out all required fields" }
    else
      redirect_to root_path, flash: { alert: "Nice try, but you can't get in that way" }
    end
  end

  def decline
    if current_user.accepted?
      current_user.update(declined: true)
      redirect_to dashboard_path, flash: { notice: "Sorry to hear you won't be able to make it :(" }
    else
      redirect_to root_path
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_hacker
    @hacker = Hacker.find(params[:id])
  end

  def authenticate
    redirect_to root_url, notice: 'Not Logged in' unless current_user
  end

  def set_transportation_methods
    @transportation_methods = ['Carnegie Mellon/University of Pittsburgh -> Ohio St',
                               'University of Iowa -> UIUC',
                               'Waterloo -> Michigan State',
                               'University of Michigan',
                               'Georgia Tech -> Rose-Hulman',
                               'Drive Separately',
                               "Purdue Student"]
  end

  def set_genders
    @genders = ['Male', 'Female', 'Other', 'Prefer Not to Specify']
  end

  def set_shirts
    @shirts = ['Small', 'Medium', 'Large', 'XL', 'XXL']
  end

  def set_races
    @races = ['White','Black or African American','Asian','American Indian or Alaskan Native','Native Hawaiian or Other Pacific Islander']
  end

  def set_ethnicities
    @ethnicities = ['Hispanic or Latino', 'Not Hispanic or Latino']
  end

  def set_job_interests
    @job_interests = ['Internship','Full time employment','Part time employment while in school','not interested']
  end

  def set_job_dates
    @job_dates = ['Spring 2016','Summer 2016','Fall 2016']
  end

  def downcase_email
    if params[:hacker]
      params[:hacker][:email].downcase! if params[:hacker][:email]
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def hacker_params
    params.require(:hacker).permit(:first_name,
     :last_name, :password, :password_digest, :password_confirmation, :school_id, :team_id, :email, :transportation_method, :confirmed, :declined, application_attributes: [ :id, :gender, :address_line_one, :address_line_two, :city, :state, :zip_code, :expected_graduation, :github, :tshirt_size, :cell_phone, :resume, :linkedin, :badge_id, :dietary_restrictions, :previous_experience, :essay, :school_other, :can_text,:major,:degree,:essay1,:essay2,:race,:ethnicity,:grad_date,:job_interest,:job_date])
  end
end
