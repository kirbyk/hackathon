Rails.application.routes.draw do
  get 'dashboard' => 'hackers#dashboard'
  get 'apply' => 'hackers#new'
  get 'login' => 'sessions#new'
  get 'logout' => 'sessions#destroy'
  get 'pages/welcome'
  root 'pages#welcome'

  get 'teams/join'

  resources :applications
  resources :schools
  resources :hackers
  resources :teams do
    get 'remove_hacker', on: :member
  end
  resources :sessions
  resources :password_resets
  resources :hacker_invitations
end
