#!/bin/bash

# Weather Forecast Application Setup Script
# This script helps set up the weather forecast application

set -e

echo "🌤️  Weather Forecast Application Setup"
echo "======================================"

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby is not installed. Please install Ruby 3.3.0 or higher."
    exit 1
fi

# Check Ruby version
RUBY_VERSION=$(ruby -v | cut -d' ' -f2 | cut -d'p' -f1)
echo "✅ Ruby version: $RUBY_VERSION"

# Check if Rails is installed
if ! command -v rails &> /dev/null; then
    echo "❌ Rails is not installed. Installing Rails..."
    gem install rails
fi

# Check if Redis is running
if ! pgrep -x "redis-server" > /dev/null; then
    echo "⚠️  Redis is not running. Please start Redis server:"
    echo "   redis-server"
    echo "   Or install Redis if not installed:"
    echo "   brew install redis  # macOS"
    echo "   sudo apt-get install redis-server  # Ubuntu"
fi

# Install dependencies
echo "📦 Installing dependencies..."
bundle install

# Set up database
echo "🗄️  Setting up database..."
rails db:create
rails db:migrate

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating environment file..."
    cat > .env << EOF
# OpenWeatherMap API Configuration
OPENWEATHER_API_KEY=your_openweather_api_key_here
OPENWEATHER_BASE_URL=https://api.openweathermap.org/data/2.5

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# Application Configuration
CACHE_DURATION_MINUTES=30
EOF
    echo "⚠️  Please edit .env file and add your OpenWeatherMap API key"
fi

# Create application.yml if it doesn't exist
if [ ! -f config/application.yml ]; then
    echo "📝 Creating application configuration..."
    cat > config/application.yml << EOF
# OpenWeatherMap API Configuration
OPENWEATHER_API_KEY: <%= ENV['OPENWEATHER_API_KEY'] || 'your_openweather_api_key_here' %>
OPENWEATHER_BASE_URL: <%= ENV['OPENWEATHER_BASE_URL'] || 'https://api.openweathermap.org/data/2.5' %>

# Redis Configuration
REDIS_URL: <%= ENV['REDIS_URL'] || 'redis://localhost:6379/0' %>

# Application Configuration
CACHE_DURATION_MINUTES: <%= ENV['CACHE_DURATION_MINUTES'] || 30 %>
EOF
fi

echo ""
echo "✅ Setup completed!"
echo ""
echo "Next steps:"
echo "1. Get your OpenWeatherMap API key from https://openweathermap.org/api"
echo "2. Edit .env file and add your API key"
echo "3. Start Redis server: redis-server"
echo "4. Start the application: rails server"
echo "5. Visit http://localhost:3000"
echo ""
echo "To run tests:"
echo "  ruby test_app.rb"
echo ""
echo "To run RSpec tests:"
echo "  bundle exec rspec"
