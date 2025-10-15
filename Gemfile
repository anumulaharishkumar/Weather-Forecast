source "https://rubygems.org"

# Core Rails
gem "rails", "~> 8.0.2", ">= 8.0.2.1"

# Database
gem "pg", "~> 1.1"

# Web server
gem "puma", ">= 5.0"

# Essential gems for our weather app
gem "httparty"
gem "redis"
gem "geocoder"
gem "jbuilder"
gem "dotenv-rails"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Basic caching (using memory store instead of Redis for now)
# gem "redis"

# CORS
gem "rack-cors"

# Development gems
group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "webmock"
  gem "vcr"
end

# Platform specific
gem "tzinfo-data", platforms: %i[ windows jruby ]
