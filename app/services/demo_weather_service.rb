# frozen_string_literal: true

# DemoWeatherService provides mock weather data for demonstration purposes
# This service simulates the OpenWeatherMap API responses for testing and demo
class DemoWeatherService
  include HTTParty

  # Initialize the service with mock data
  def initialize
    @cache_duration = 30.minutes
  end

  # Retrieves mock current weather data for a given location
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @param units [String] Temperature units (metric, imperial, kelvin)
  # @return [Hash] Mock weather data hash containing current conditions
  def current_weather(latitude, longitude, units = 'metric')
    cache_key = "demo_weather:current:#{latitude}:#{longitude}:#{units}"
    
    Rails.cache.fetch(cache_key, expires_in: @cache_duration) do
      generate_mock_current_weather(latitude, longitude, units)
    end
  end

  # Retrieves mock 5-day weather forecast for a given location
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @param units [String] Temperature units (metric, imperial, kelvin)
  # @return [Hash] Mock forecast data hash containing 5-day weather predictions
  def forecast(latitude, longitude, units = 'metric')
    cache_key = "demo_weather:forecast:#{latitude}:#{longitude}:#{units}"
    
    Rails.cache.fetch(cache_key, expires_in: @cache_duration) do
      generate_mock_forecast(latitude, longitude, units)
    end
  end

  # Retrieves both current weather and forecast data
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @param units [String] Temperature units (metric, imperial, kelvin)
  # @return [Hash] Combined mock weather data
  def weather_data(latitude, longitude, units = 'metric')
    {
      current: current_weather(latitude, longitude, units),
      forecast: forecast(latitude, longitude, units),
      cached: false
    }
  end

  private

  # Generates mock current weather data
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @param units [String] Temperature units
  # @return [Hash] Mock current weather data
  def generate_mock_current_weather(latitude, longitude, units)
    base_temp = case units
                when 'metric' then 22.0
                when 'imperial' then 71.6
                when 'kelvin' then 295.15
                else 22.0
                end

    {
      temperature: base_temp + rand(-5.0..5.0).round(1),
      feels_like: base_temp + rand(-3.0..3.0).round(1),
      humidity: rand(40..80),
      pressure: rand(1000..1020),
      description: ['clear sky', 'partly cloudy', 'cloudy', 'sunny', 'overcast'].sample,
      icon: ['01d', '02d', '03d', '04d', '50d'].sample,
      wind_speed: rand(1.0..8.0).round(1),
      wind_direction: rand(0..360),
      visibility: rand(8000..12000),
      uv_index: rand(1..10),
      timestamp: Time.current,
      location: {
        name: get_location_name(latitude, longitude),
        country: 'US',
        latitude: latitude,
        longitude: longitude
      }
    }
  end

  # Generates mock forecast data
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @param units [String] Temperature units
  # @return [Hash] Mock forecast data
  def generate_mock_forecast(latitude, longitude, units)
    base_temp = case units
                when 'metric' then 22.0
                when 'imperial' then 71.6
                when 'kelvin' then 295.15
                else 22.0
                end

    daily_forecasts = (0..4).map do |day_offset|
      date = Date.current + day_offset.days
      high = base_temp + rand(2.0..8.0).round(1)
      low = base_temp - rand(2.0..6.0).round(1)
      
      {
        date: date,
        high: high,
        low: low,
        description: ['sunny', 'partly cloudy', 'cloudy', 'clear sky'].sample,
        icon: ['01d', '02d', '03d', '04d'].sample,
        humidity: rand(50..85),
        wind_speed: rand(2.0..6.0).round(1)
      }
    end

    {
      location: {
        name: get_location_name(latitude, longitude),
        country: 'US',
        latitude: latitude,
        longitude: longitude
      },
      daily_forecasts: daily_forecasts
    }
  end

  # Gets a location name based on coordinates
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @return [String] Location name
  def get_location_name(latitude, longitude)
    # Simple location mapping based on coordinates
    if latitude.between?(40.0, 42.0) && longitude.between?(-75.0, -73.0)
      'New York'
    elsif latitude.between?(33.0, 35.0) && longitude.between?(-119.0, -117.0)
      'Los Angeles'
    elsif latitude.between?(41.0, 43.0) && longitude.between?(-88.0, -86.0)
      'Chicago'
    elsif latitude.between?(29.0, 31.0) && longitude.between?(-96.0, -94.0)
      'Houston'
    elsif latitude.between?(25.0, 27.0) && longitude.between?(-81.0, -79.0)
      'Miami'
    else
      'Demo City'
    end
  end
end
