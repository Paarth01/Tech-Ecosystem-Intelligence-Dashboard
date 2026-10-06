class ApplicationController < ActionController::API
  include ActionController::Cookies

  COOKIE = :techintel_session

  before_action :require_ajax_header
  before_action :authenticate!

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "Not found" }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: "Missing parameter: #{e.param}" }, status: :bad_request
  end

  # Two requests racing to create the same record: the database's unique index stops the second one.
  rescue_from ActiveRecord::RecordNotUnique do
    render json: { error: "That already exists" }, status: :conflict
  end

  private

  # CSRF protection for cookie logins: browsers can't add a custom header to a cross-site
  # request without our permission, so requiring one on every write blocks forged requests.
  def require_ajax_header
    return if request.get? || request.head?
    return if request.headers["X-Requested-With"] == "XMLHttpRequest"
    render json: { error: "Invalid request" }, status: :forbidden
  end

  def current_session
    return @current_session if defined?(@current_session)
    @current_session = Session.find_by_token(cookies[COOKIE])
    # The server slides the session forward when it is used; the browser cookie has to follow,
    # otherwise it would expire 30 days after login no matter how often the person comes back.
    set_session_cookie(cookies[COOKIE]) if @current_session&.renewed
    @current_session
  end

  # The signed-in user. Every controller must reach data through this method so one user
  # can never touch another user's records.
  def current_user
    current_session&.user
  end

  def authenticate!
    render json: { error: "Please sign in" }, status: :unauthorized unless current_user
  end

  def start_session(user)
    set_session_cookie(Session.start(user))
  end

  def set_session_cookie(token)
    cookies[COOKIE] = { value: token, httponly: true, same_site: :lax,
                        secure: request.ssl?, expires: Session::TTL.from_now }
  end

  def end_session
    current_session&.destroy
    cookies.delete(COOKIE)
  end

  # Allows `limit` calls per window, otherwise answers 429. Meant for before_action. By default the
  # limit is per signed-in user; pass `by:` (for example the IP address) for public endpoints.
  def throttle!(name, limit:, within:, by: current_user&.id)
    seconds = within.to_i
    window = Time.current.to_i / seconds
    return if Throttle.hit("throttle:#{name}:#{by}:#{window}", within: within) <= limit

    render_too_many(((window + 1) * seconds) - Time.current.to_i)
  end

  def render_too_many(retry_after)
    response.set_header("Retry-After", retry_after.to_s)
    render json: { error: "You're doing that too often. Try again in #{(retry_after / 60.0).ceil} minute(s)." },
           status: :too_many_requests
  end

  def render_errors(record)
    render json: { error: record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end
end
