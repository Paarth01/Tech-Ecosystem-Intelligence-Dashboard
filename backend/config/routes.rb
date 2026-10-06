Rails.application.routes.draw do
  namespace :api do
    get    "auth/options",         to: "auth#options"
    post   "auth/register", to: "auth#register"
    post   "auth/login",    to: "auth#login"
    delete "auth/logout",   to: "auth#logout"
    post   "auth/forgot_password", to: "auth#forgot_password"
    post   "auth/reset_password",  to: "auth#reset_password"
    post   "auth/verify_email",    to: "auth#verify_email"

    get   "me", to: "users#show"
    patch "me", to: "users#update"
    delete "me", to: "users#destroy"
    post  "me/verification", to: "users#resend_verification"

    get  "dashboard",         to: "dashboard#show"
    post "dashboard/refresh", to: "dashboard#refresh"
    get "search",    to: "search#show"

    resources :saved_articles, only: %i[index create destroy]
    resources :comparisons, only: %i[index show create destroy] do
      post :generate, on: :collection
    end
  end

  # Health check for load balancers and uptime monitors (no login, no database, no outbound calls).
  get "up", to: "rails/health#show"

  # Everything else is the React app. Paths with a dot (assets) are left to the static file server.
  root "frontend#index"
  get "*path", to: "frontend#index", format: false,
               constraints: ->(request) { !request.path.start_with?("/api/") && !request.path.include?(".") }
end
