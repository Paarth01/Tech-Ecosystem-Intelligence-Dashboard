threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count
port ENV.fetch("PORT", 3000)

# Finish running requests (and queued emails) before exiting on a restart or deploy.
force_shutdown_after ENV.fetch("PUMA_SHUTDOWN_TIMEOUT", 30).to_i
plugin :tmp_restart
