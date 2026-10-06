module Api
  class UsersController < ApplicationController
    # Checking a password is slow on purpose; limit it so a stolen session can't be used to guess it.
    before_action(only: :destroy) { throttle!("password-check", limit: 10, within: 15.minutes) }
    before_action(only: :update, if: -> { params[:password].present? }) { throttle!("password-check", limit: 10, within: 15.minutes) }
    before_action(only: :resend_verification) { throttle!("resend-verification", limit: 3, within: 1.hour) }

    def show
      render json: account_json
    end

    def update
      user = current_user
      user.name = params[:name].is_a?(String) ? params[:name] : "" if params.key?(:name)

      changing_password = params[:password].present?
      if changing_password
        return wrong_password unless user.authenticate(params[:current_password].to_s)
        user.password = params[:password]
      end

      if user.save
        # A new password signs out every other device; this one stays signed in.
        user.sessions.where.not(id: current_session.id).destroy_all if changing_password
        render json: account_json
      else
        render_errors(user)
      end
    end

    def resend_verification
      current_user.send_verification_email unless current_user.email_verified?
      render json: { ok: true }
    end

    # Deletes the account and everything saved in it.
    def destroy
      return wrong_password unless current_user.authenticate(params[:current_password].to_s)

      current_user.destroy
      cookies.delete(COOKIE)
      head :no_content
    end

    private

    def wrong_password
      render json: { error: "Current password is incorrect" }, status: :unprocessable_entity
    end

    def account_json
      { user: current_user.public_json,
        member_since: current_user.created_at,
        saved_count: current_user.saved_articles.count,
        comparison_count: current_user.comparisons.count }
    end
  end
end
