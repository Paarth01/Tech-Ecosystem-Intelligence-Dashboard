namespace :cache do
  desc "Delete expired entries from the file cache (rate-limit counters and search results pile up otherwise). Run daily, e.g. from cron."
  task prune: :environment do
    Rails.cache.cleanup
    puts "Expired cache entries removed."
  end
end
