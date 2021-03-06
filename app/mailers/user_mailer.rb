class UserMailer < ActionMailer::Base
  default from: "BoilerMake Team <noresponse@boilermake.org>"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.password_reset.subject
  #
  def password_reset user
    @user = user
    mail to: user.email, subject: 'Password Reset'
  end

  def welcome_email user
    @user = user
    mail to: @user.email, subject: "#{HACKATHON} - Hype intensifies"
  end
end
