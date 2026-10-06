module Api
  class AuthController < ApplicationController
    PUBLIC_ACTIONS = %i[options register login forgot_password reset_password verify_email].freeze
    LOGIN_LOCKOUT = 15.minutes
    MAX_FAILED_PER_PAIR = 10    # one email address tried from one IP address
    MAX_FAILED_PER_EMAIL = 40   # one email address tried from anywhere (distributed guessing)
    MAX_FAILED_PER_IP = 30      # one IP address trying any addresses

    skip_before_action :authenticate!, only: PUBLIC_ACTIONS

    before_action(only: :register) { throttle!("register", limit: 10, within: 1.hour, by: request.remote_ip) }
    before_action(only: :forgot_password) { throttle!("forgot", limit: 5, within: 1.hour, by: request.remote_ip) }
    before_action(only: :reset_password) { throttle!("reset", limit: 20, within: 1.hour, by: request.remote_ip) }

    # Lets the sign-up form know whether an invite code is needed.
    def options
      render json: { invite_required: signup_code.present?, email_first: email_first_signup? }
    end

    def register
      if signup_code.present? && !ActiveSupport::SecurityUtils.secure_compare(params[:invite_code].to_s, signup_code)
        return render json: { error: "That invite code isn't valid" }, status: :unprocessable_entity
      end

      user = User.new(params.permit(:name, :email, :password))
      return register_email_first(user) if email_first_signup?

      if user.save
        start_session(user)
        user.send_verification_email
        render json: { user: user.public_json }, status: :created
      else
        render_errors(user)
      end
    end

    # Repeated wrong passwords lock a login for a while. The main lock is per (email, IP) pair, so a
    # stranger guessing from their own address can't lock the real owner out; the wider per-email and
    # per-IP limits still stop guessing spread across many addresses. Windows are fixed, so
    # repeated attempts can't extend a lock.
    def login
      email = params[:email].to_s.strip.downcase
      keys = login_keys(email)
      if Throttle.count(keys[:pair]) >= MAX_FAILED_PER_PAIR ||
         Throttle.count(keys[:email]) >= MAX_FAILED_PER_EMAIL ||
         Throttle.count(keys[:ip]) >= MAX_FAILED_PER_IP
        return render_too_many(LOGIN_LOCKOUT.to_i)
      end

      user = User.sign_in(email, params[:password])
      if user && email_first_signup? && !user.email_verified?
        return render json: { error: "Please confirm your email address first. The link we sent works for 3 days; " \
                                     "\"Forgot your password?\" sends a new one." }, status: :forbidden
      end

      if user
        Throttle.clear(keys[:pair])
        start_session(user)
        render json: { user: user.public_json }
      else
        keys.each_value { |key| Throttle.hit(key, within: LOGIN_LOCKOUT, sliding: false) }
        render json: { error: "Invalid email or password" }, status: :unauthorized
      end
    end

    # Ends this browser's session only; other devices stay signed in.
    def logout
      end_session
      head :no_content
    end

    # Always answers the same way, and does the same work before answering (the lookup and the
    # email happen in a background job), so neither the reply nor its timing reveals who has an account.
    def forgot_password
      email = params[:email].to_s.strip.downcase
      PasswordResetJob.perform_later(email) if Throttle.hit("forgot-email:#{Throttle.fingerprint(email)}", within: 1.hour) <= 3
      render json: { ok: true }
    end

    def reset_password
      token = EmailToken.find_live(params[:token], "password_reset")
      return render json: { error: "This reset link is invalid or has expired." }, status: :unprocessable_entity unless token

      user = token.user
      user.password = params[:password].to_s
      user.email_verified_at ||= Time.current   # receiving the email proves the address is theirs
      return render_errors(user) unless user.save

      user.email_tokens.where(purpose: "password_reset").destroy_all
      user.sessions.destroy_all                  # sign out everywhere, including whoever knew the old password
      render json: { ok: true }
    end

    def verify_email
      token = EmailToken.find_live(params[:token], "email_verification")
      return render json: { error: "This verification link is invalid or has expired." }, status: :unprocessable_entity unless token

      token.user.update!(email_verified_at: Time.current)
      token.destroy
      render json: { ok: true }
    end

    private

    def signup_code
      ENV["SIGNUP_CODE"].presence
    end

    # With EMAIL_FIRST_SIGNUP=true, registering never signs anyone in and the answer is identical
    # whether or not the address already has an account, so sign-up can't be used to find out who
    # is registered. A new address gets a confirmation link; an existing one gets a notice instead.
    def register_email_first(user)
      taken = user.tap(&:valid?).errors.details[:email].any? { |detail| detail[:error] == :taken }
      problems = user.errors.reject { |error| error.attribute == :email && error.type == :taken }
      return render json: { error: problems.map(&:full_message).to_sentence }, status: :unprocessable_entity if problems.any?

      # At most two such emails per address per hour, so sign-up can't be used to mail-bomb someone.
      if Throttle.hit("register-mail:#{Throttle.fingerprint(user.email)}", within: 1.hour) <= 2
        if taken
          UserMailer.account_exists(User.find_by!(email: user.email).id).deliver_later
        else
          user.save!
          user.send_verification_email
        end
      end
      render json: { ok: true, verify_email: true }, status: :accepted
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      render json: { ok: true, verify_email: true }, status: :accepted   # a racing sign-up for the same address
    end

    def email_first_signup?
      ENV["EMAIL_FIRST_SIGNUP"] == "true"
    end

    def login_keys(email)
      { pair: "login-failed:pair:#{Throttle.fingerprint("#{email}|#{request.remote_ip}")}",
        email: "login-failed:email:#{Throttle.fingerprint(email)}",
        ip: "login-failed:ip:#{request.remote_ip}" }
    end
  end
end
