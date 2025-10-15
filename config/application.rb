require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WeatherForecastApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = false

    # Load custom configuration
    config.before_configuration do
      config_file = Rails.root.join('config', 'application.yml')
      if File.exist?(config_file)
        config_hash = YAML.load_file(config_file)
        config_hash.each do |key, value|
          config.send("#{key.downcase}=", value)
        end
      end
    end

    # Weather API configuration
    config.openweather_api_key = ENV['OPENWEATHER_API_KEY'] || 'edeb8ac0efddebf91691e8ac1aa4abbf'
    config.openweather_base_url = ENV['OPENWEATHER_BASE_URL'] || 'https://api.openweathermap.org/data/2.5'
    config.cache_duration_minutes = ENV['CACHE_DURATION_MINUTES']&.to_i || 30

    # Redis configuration
    config.redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
  end
end
