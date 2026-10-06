# Runs several slow tasks (HTTP calls) at the same time. A task that raises
# returns { error: e } instead of breaking the others.
#   Fanout.run(a: -> { ... }, b: -> { ... })  # => { a: { value: ... }, b: { error: e } }
module Fanout
  def self.run(tasks)
    threads = tasks.transform_values do |task|
      Thread.new do
        Rails.application.executor.wrap do
          { value: task.call }
        rescue StandardError => e
          Rails.logger.warn("[fanout] #{e.class}: #{e.message}")
          { error: e }
        end
      end
    end
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
      threads.transform_values(&:value)
    end
  end
end
