# Serves the built React app (backend/public/index.html) for every non-API URL, so deep links
# like /comparisons/12 work after a refresh. In development the app runs on Vite instead.
class FrontendController < ActionController::API
  def index
    file = Rails.public_path.join("index.html")
    return render(plain: "The frontend isn't built yet. Run `npm run build` in the frontend folder, " \
                         "or use http://localhost:5173 while developing.", status: :not_found) unless file.exist?

    response.set_header("Content-Security-Policy", Rails.configuration.x.csp)
    send_file file, type: "text/html", disposition: "inline"
  end
end
