class Ability
  include CanCan::Ability

  def initialize(user)
    can :create, Hacker
    if user.present?
      if user.exec?
        can :manage, :all
      elsif user.hacker?
        can :manage, [Application, Team]
        can [ :dashboard, :new, :create, :update, :confirm ], Hacker
        can [ :index ], School
      end
    end
    can :index, Update
  end
end
