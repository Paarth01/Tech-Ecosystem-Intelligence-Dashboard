namespace :db do
  desc "Copy the SQLite database into backups/ (safe while the app is running). KEEP=14 sets how many to keep."
  task backup: :environment do
    config = ActiveRecord::Base.connection_db_config
    abort "db:backup only works with SQLite. For PostgreSQL use pg_dump." unless config.adapter == "sqlite3"

    dir = Rails.root.join("backups")
    FileUtils.mkdir_p(dir)
    file = dir.join("#{Rails.env}-#{Time.now.utc.strftime('%Y%m%d-%H%M%S-%L')}.sqlite3")
    ActiveRecord::Base.connection.execute("VACUUM INTO #{ActiveRecord::Base.connection.quote(file.to_s)}")

    keep = ENV.fetch("KEEP", "14").to_i
    Dir[dir.join("#{Rails.env}-*.sqlite3")].sort.reverse.drop(keep).each { |old| File.delete(old) }
    puts "Backup written to #{file}"
  end
end
