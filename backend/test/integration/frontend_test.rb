require "test_helper"

class FrontendTest < ActionDispatch::IntegrationTest
  INDEX = Rails.public_path.join("index.html")

  teardown { File.delete(INDEX) if @created && File.exist?(INDEX) }

  def build_frontend
    FileUtils.mkdir_p(Rails.public_path)
    File.write(INDEX, "<!doctype html><div id=root></div>")
    @created = true
  end

  test "shows a helpful message when the frontend has not been built" do
    skip "a built frontend already exists in public/" if INDEX.exist?
    get "/"
    assert_response :not_found
    assert_includes response.body, "npm run build"
  end

  test "serves the app for the root and for deep links, with a strict content security policy" do
    build_frontend
    ["/", "/comparisons/12", "/research"].each do |path|
      get path
      assert_response :success, path
      assert_includes response.body, 'id=root'
      assert_includes response.headers["Content-Security-Policy"].to_s, "script-src 'self'", "#{path} needs the policy header"
    end
  end

  test "unknown api paths and missing asset files stay 404 instead of returning the app" do
    build_frontend
    ["/api/nope", "/assets/missing.js"].each do |path|
      assert_raises(ActionController::RoutingError, path) { Rails.application.routes.recognize_path(path) }
    end
  end
end
