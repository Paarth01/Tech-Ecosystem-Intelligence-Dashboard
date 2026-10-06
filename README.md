# Tech Ecosystem Intelligence

A small full-stack app that shows what is gaining traction across GitHub, Hacker News, Dev.to,
Lobsters and Stack Overflow. Sign in to save articles, research project ideas, and compare
articles side by side. Everything you save is private to your account.

- **Frontend:** React + JavaScript (Vite), plain CSS
- **Backend:** Ruby on Rails 8.1 (API mode), REST + JSON
- **Database:** SQLite by default, PostgreSQL optional

```
backend/    Rails API (accounts, saved articles, comparisons, trend fetching)
frontend/   React app
```

## What you can do

- Register, sign in, sign out, edit your name, change your password
- **Dashboard:** top topic, trending technologies and five community feeds, filterable by ecosystem
- **Research:** search GitHub, Dev.to, Reddit and Stack Overflow for a project idea
- **Save** and remove articles, and view your saved list
- **Compare** 2 to 4 articles, then save the comparison, reopen it later, or delete it
- `Ctrl/Cmd + K` opens a quick search; light and dark theme

## Setup

You need **Ruby 3.3+** and **Node 22.12+**.

### 1. Start the API (terminal 1)

```bash
cd backend
bundle install
bin/rails db:create db:migrate
bin/rails server          # http://localhost:3000
```

### 2. Start the web app (terminal 2)

```bash
cd frontend
npm install
npm run dev               # http://localhost:5173
```

Open **http://localhost:5173**, create an account, and you are in. The dev server forwards `/api`
requests to Rails, so there is nothing else to configure.

### Optional environment variables

Export these in the terminal before running `bin/rails server`.

| Variable | What it does |
| --- | --- |
| `GEMINI_API_KEY` | Enables AI-written comparisons. Without it, comparisons show a plain side-by-side table. |
| `GEMINI_MODEL` | Gemini model to use. Defaults to `gemini-3.5-flash`. Google retires models regularly; if the app says the model was not found, set this to a current one. |
| `GEMINI_DAILY_LIMIT` | Most AI comparisons per day for the whole app (default 300). A hard stop on cost. Only successful answers count. |
| `GEMINI_MAX_OUTPUT_TOKENS` | Cap on the length of one AI answer (default 4096). Bounds the cost of a single comparison. |
| `GITHUB_TOKEN` | Raises the GitHub API limit from 60 to 5,000 requests per hour. Recommended. |
| `SIGNUP_CODE` | If set, registering requires this invite code. Use it to keep a public site closed. |
| `REQUIRE_VERIFIED_EMAIL` | Only users who confirmed their email get AI comparisons. **On by default in production** (so a flood of sign-ups can't use up the shared AI allowance); set `false` to allow everyone. Off by default in development. |
| `EMAIL_FIRST_SIGNUP` | Set to `true` to stop sign-up revealing which emails already have an account. Registering then never signs anyone in: a new address gets a confirmation link, an existing one gets a "you already have an account" notice, and the page says the same thing either way. Sign-in requires a confirmed email. Needs working email. Accounts created before you switch it on must use "Forgot your password?" once (that also confirms the address). |
| `ERROR_WEBHOOK_URL` | Sends unexpected server errors to a Slack/Discord-style webhook (at most 20 per hour). |

**Emails.** Password reset and email confirmation send emails. While developing, they are written to
`backend/tmp/mails/` (one file per recipient) instead of being sent, so open that file to find the link.
In production, set `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAIL_FROM` and `APP_URL`
(the public address of the app, used in email links). **The server refuses to start without `APP_URL` and
`SMTP_ADDRESS`**, because reset links would otherwise point at localhost or never arrive. To run without
email on purpose, set `ALLOW_NO_EMAIL=true`; users then cannot reset passwords or verify their address, so
AI comparisons stay off unless you also set `REQUIRE_VERIFIED_EMAIL=false`. Temporary failures (network trouble, a busy
mail server) are retried up to 5 times; permanent ones, such as a rejected address, are not. Emails are sent from inside the web process, so restart gracefully (Puma waits up to 30
seconds); for stronger guarantees use a database-backed queue such as Solid Queue.

## Run the tests

```bash
cd backend  && bin/rails test      # accounts, email links, lockouts, data isolation, limits, data sources, Gemini
cd frontend && npm test            # API client, route protection, switching users, full user journeys
```

The backend tests replace GitHub, Hacker News, Gemini and the other sites with sample responses, so they
run offline. The frontend journey tests drive the real screens against a small in-memory copy of the API:
register, save, compare, delete, account deletion, and a second user seeing none of the first user's data.
A GitHub Actions workflow (`.github/workflows/ci.yml`) runs both suites and a build, and Dependabot
(`.github/dependabot.yml`) opens weekly update pull requests.

## Deploy as one app

Rails serves the built React app itself, so there is one server and one domain.

```bash
cd frontend && npm install && npm run build      # writes the app into backend/public
cd ../backend
bundle install                                   # first time only: commit the Gemfile.lock it creates
export RAILS_ENV=production SECRET_KEY_BASE=$(bin/rails secret) GEMINI_API_KEY=... GITHUB_TOKEN=...
export APP_URL=https://news.example.com SMTP_ADDRESS=smtp.example.com SMTP_USERNAME=... SMTP_PASSWORD=...
bin/rails db:create db:migrate
bin/rails server -b 0.0.0.0
```

| Variable | What it does |
| --- | --- |
| `FORCE_SSL` | On by default in production: redirects to https and marks the login cookie `Secure`. Run behind HTTPS (or a proxy that sets `X-Forwarded-Proto`). Set `FORCE_SSL=false` only to try production mode locally over http. |
| `APP_HOST` | Optional. Comma-separated domain(s) the app answers to. Defaults to the host of `APP_URL`. |
| `MAX_REQUEST_BYTES` | Largest request body the app accepts (default 262144 = 256 KB); bigger ones get `413` before anything is parsed. |
| `PUMA_SHUTDOWN_TIMEOUT` | Seconds Puma waits for running requests on shutdown (default 30). |
| `DATABASE_URL` | Optional. Use PostgreSQL (see below). |

Also set a request body size limit (for example `client_max_body_size 100k;` in nginx) at your proxy; the app
has its own limit as a second line of defence. `GET /up` is a health check for load balancers (no login, plain
http allowed). A `Dockerfile` is included (untested: build it and check the `/up` health check first). The logs
hide passwords, tokens, the invite code and email addresses, but your proxy's access log records query strings,
so switch off or scrub it for `/reset-password` and `/verify-email`.

**Dependencies.** Commit `backend/Gemfile.lock`. CI fails without it and runs Brakeman, `bundler-audit` and
`npm audit`.

**Cache cleanup.** Run `bin/rails cache:prune` daily from cron: the file cache otherwise keeps expired
rate-limit and search entries on disk.
Rate limits use the visitor's IP address. If you put a CDN or load balancer in front of Rails, set
`TRUSTED_PROXIES` to its address ranges (comma separated, for example `TRUSTED_PROXIES=203.0.113.0/24`) so Rails
sees each visitor's real address; otherwise everyone looks like the proxy and the IP limits apply to all users together.

**Commands that start the app in production** (`db:prepare`, `rails runner`, a Docker build step that boots Rails)
need the same settings as the server: `SECRET_KEY_BASE`, `APP_URL` and `SMTP_ADDRESS` (or `ALLOW_NO_EMAIL=true`).

**Backups (SQLite).** `bin/rails db:backup` copies the database into `backend/backups/` while the app is
running and keeps the newest 14 (`KEEP=30` to change). Run it from cron, and copy the files off the server.
With PostgreSQL, use `pg_dump` instead.

**One server only.** Rate limits, caches and the SQLite file live on the server's disk, which is right for a
single server. To run several servers you would need PostgreSQL and a shared cache store.

## Use PostgreSQL instead of SQLite

1. In `backend/Gemfile`, uncomment the `pg` line and run `bundle install`.
2. Set `DATABASE_URL`, for example `export DATABASE_URL=postgres://user:password@localhost/techintel`.
3. Run `bin/rails db:create db:migrate`.

## How it works

**Sign-in.** Signing in creates a session: a random token kept in an `HttpOnly`, `SameSite=Lax` cookie
that JavaScript cannot read. The database stores only a SHA-256 hash of the token. Each device has its
own session, sessions expire after 30 days without use, signing out ends only that device, and changing
your password signs out every other device. Passwords are hashed with bcrypt.

**Protected routes.** In the browser, every page except Login and Register needs a signed-in user. On the
server, every endpoint except register and login returns `401` without a valid session.

**Private data.** Controllers never look up records by id alone. They always go through the signed-in
user (`current_user.saved_articles.find(id)`), so another user's record returns `404`.

**Password reset and email confirmation.** Both use single-use links that are emailed. Only a hash of each
link's token is stored; reset links last 1 hour and confirmation links 3 days. Asking for a new link cancels
the old one. Resetting a password signs out every device. "Forgot password" gives the same answer whether or
not an account exists, so it can't be used to find out who is registered.

**Other protections.**
- *Guessing passwords:* 10 wrong passwords for one email address from one IP address lock that pair for 15
  minutes (even for the right password); 40 from any addresses lock the email address, and 30 failed logins
  lock an IP address. The windows are fixed, so repeated attempts don't extend them. Because the first limit is
  per pair, a stranger can't lock the real owner out from another address. Checking a password inside an
  account is limited too.
- *Sign-up abuse:* 10 registrations per hour per IP, an optional invite code (`SIGNUP_CODE`), and an optional
  verified-email requirement for AI comparisons.
- *Forged requests:* every write must carry an `X-Requested-With` header, which other websites cannot add.
- *Cost control:* per user, comparisons are limited to 10 per hour, searches to 30 per hour, and manual
  dashboard refreshes (a `POST`) to 3 per 10 minutes (answered with `429`). AI comparisons also have an app-wide
  daily cap.
- *Size limits:* text fields are trimmed, a user can keep up to 500 saved articles and 100 comparisons,
  and comparison results are capped at 20,000 characters.
- *Links:* only `http` and `https` links are accepted or shown.
- *Content Security Policy:* the app only runs its own scripts, which limits what an injected script could do.
- *Login timing:* an unknown email takes as long to reject as a wrong password.
- *Account deletion:* from the Account page, with the password. It removes the account and everything in it.

**Trends.** Rails fetches the five sources in parallel and caches each for one hour. A source that fails
is skipped for a minute instead of slowing every request, and a failed refresh never replaces older good
data.

**Scoring.** Topic score = (sum, over the items that mention it, of source weight x engagement factor) x
(1 + log2(number of platforms) x 0.8). The engagement factor runs from 0.5 for an item nobody engaged with to
1.5 for the most engaged item on its own source (stars this week, points, reactions), so GitHub's big numbers
don't drown out Hacker News. A technology on several platforms outranks one repeated on a single platform.

**Rising and falling.** Once an hour the dashboard saves the topic scores. Each topic then shows how its score
changed compared with a snapshot at least a day old (`↑ 24%`, `↓ 10%`, or `New`). Nothing is shown during the
first day. Snapshots are kept for 30 days.

## API

All endpoints are under `/api`, need a signed-in session unless marked public, and every write needs the
`X-Requested-With: XMLHttpRequest` header (the React app adds it).

| Method and path | Purpose |
| --- | --- |
| `POST /auth/register`, `POST /auth/login`, `GET /auth/options` (all public), `DELETE /auth/logout` | Account session |
| `POST /auth/forgot_password`, `POST /auth/reset_password`, `POST /auth/verify_email` (all public) | Emailed links |
| `GET /me`, `PATCH /me`, `DELETE /me` | Account details; update name or password; delete the account |
| `POST /me/verification` | Send the confirmation email again |
| `GET /dashboard` | Topics, ecosystems and the five feeds (cached for an hour) |
| `POST /dashboard/refresh` | Same, skipping the cache (limited to 3 per 10 minutes) |
| `GET /up` | Health check (no login) |
| `GET /search?q=` | Research an idea |
| `GET /saved_articles`, `POST /saved_articles`, `DELETE /saved_articles/:id` | Your saved articles |
| `POST /comparisons/generate` | Build a comparison from 2 to 4 articles (not saved) |
| `GET /comparisons`, `GET /comparisons/:id`, `POST /comparisons`, `DELETE /comparisons/:id` | Your saved comparisons |

## Good to know

- Not included: CAPTCHA (use `SIGNUP_CODE` to keep a public site closed), changing your email address, two-factor
  sign-in, and an admin area.
- Browser tests: the journey tests run in a simulated browser (jsdom). Nothing here drives a real browser, so
  check the layout yourself on a phone and a desktop.
- Reddit often blocks requests from cloud servers. If it does, that section shows a short notice and the
  other sources still work.
- The previous Next.js version was replaced by this Rails + React version. Its trend scoring and topic
  detection were ported to `backend/app/services`.
