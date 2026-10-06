# Production image: builds the React app, then runs Rails (which serves it) as a non-root user.
# Not built or run as part of the audit fixes: try `docker build -t tech-dashboard .` first.

FROM node:22-slim AS frontend
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
# Vite writes the build to ../backend/public
RUN mkdir -p /app/backend && npm run build

FROM ruby:3.4-slim
RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential libyaml-dev curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app/backend
ENV RAILS_ENV=production BUNDLE_WITHOUT="development:test" BUNDLE_DEPLOYMENT=1

COPY backend/Gemfile backend/Gemfile.lock ./
RUN bundle install
COPY backend/ ./
COPY --from=frontend /app/backend/public ./public

# The database, cache and backups live under /app/backend/storage-like paths: mount a volume there.
RUN useradd --create-home app && mkdir -p db tmp log backups && chown -R app:app db tmp log backups
USER app
VOLUME ["/app/backend/db", "/app/backend/tmp", "/app/backend/backups"]

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s CMD curl -fsS http://localhost:3000/up || exit 1
# Required environment: SECRET_KEY_BASE, APP_URL, SMTP_ADDRESS (or ALLOW_NO_EMAIL=true). See README.
CMD ["sh", "-c", "bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0"]
