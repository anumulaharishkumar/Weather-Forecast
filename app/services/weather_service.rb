# frozen_string_literal: true

require 'httparty'
require 'json'

# WeatherService handles all weather-related API interactions
# This service encapsulates the OpenWeatherMap API integration and provides
# a clean interface for retrieving weather data with caching support
class WeatherService
  include HTTParty

  # Base URL for OpenWeatherMap API
  BASE_URL = 'https://api.openweathermap.org/data/2.5'.freeze

  # Initialize the service with API key and optional base URL
  # @param api_key [String] OpenWeatherMap API key
  # @param base_url [String] Optional base URL for API (useful for testing)
  def initialize(api_key = nil, base_url = BASE_URL)
    @api_key = api_key || Rails.application.config.openweather_api_key
    @base_url = base_url
    @cache_duration = Rails.application.config.cache_duration_minutes.minutes
  end

  # Retrieves current weather data for a given location
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @param units [String] Temperature units (metric, imperial, kelvin)
  # @param postal_code [String] Optional postal code for caching
  # @return [Hash] Weather data hash containing current conditions
  # @raise [StandardError] If API request fails or returns error
  def current_weather(latitude, longitude, units = 'metric', postal_code = nil)
    # Use postal code for caching if available, otherwise fall back to coordinates
    cache_identifier = postal_code || "#{latitude}:#{longitude}"
    cache_key = "weather:current:#{cache_identifier}:#{units}"
    
    Rails.cache.fetch(cache_key, expires_in: @cache_duration) do
      response = make_api_request('weather', {
        lat: latitude,
        lon: longitude,
        units: units,
        appid: @api_key
      })
      
      parse_weather_response(response)
    end
  end

  # Retrieves 5-day weather forecast for a given location
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @param units [String] Temperature units (metric, imperial, kelvin)
  # @param postal_code [String] Optional postal code for caching
  # @return [Hash] Forecast data hash containing 5-day weather predictions
  # @raise [StandardError] If API request fails or returns error
  def forecast(latitude, longitude, units = 'metric', postal_code = nil)
    # Use postal code for caching if available, otherwise fall back to coordinates
    cache_identifier = postal_code || "#{latitude}:#{longitude}"
    cache_key = "weather:forecast:#{cache_identifier}:#{units}"
    
    Rails.cache.fetch(cache_key, expires_in: @cache_duration) do
      response = make_api_request('forecast', {
        lat: latitude,
        lon: longitude,
        units: units,
        appid: @api_key
      })
      
      parse_forecast_response(response)
    end
  end

  # Retrieves both current weather and forecast data
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @param units [String] Temperature units (metric, imperial, kelvin)
  # @param postal_code [String] Optional postal code for caching
  # @return [Hash] Combined weather data containing current and forecast information
  def weather_data(latitude, longitude, units = 'metric', postal_code = nil)
    {
      current: current_weather(latitude, longitude, units, postal_code),
      forecast: forecast(latitude, longitude, units, postal_code),
      cached: false # This will be set by the controller if data comes from cache
    }
  end

  private

  # Makes HTTP request to OpenWeatherMap API
  # @param endpoint [String] API endpoint (weather, forecast, etc.)
  # @param params [Hash] Query parameters for the request
  # @return [Hash] Parsed JSON response
  # @raise [StandardError] If request fails or returns error status
  def make_api_request(endpoint, params)
    url = "#{@base_url}/#{endpoint}"
    
    response = self.class.get(url, query: params)
    
    unless response.success?
      error_message = response.parsed_response&.dig('message') || 'Unknown API error'
      raise StandardError, "Weather API error: #{error_message} (Status: #{response.code})"
    end
    
    response.parsed_response
  rescue HTTParty::Error => e
    raise StandardError, "Network error: #{e.message}"
  end

  # Parses current weather API response into standardized format
  # @param response [Hash] Raw API response
  # @return [Hash] Standardized weather data
  def parse_weather_response(response)
    {
      temperature: response.dig('main', 'temp'),
      feels_like: response.dig('main', 'feels_like'),
      humidity: response.dig('main', 'humidity'),
      pressure: response.dig('main', 'pressure'),
      description: response.dig('weather', 0, 'description'),
      icon: response.dig('weather', 0, 'icon'),
      wind_speed: response.dig('wind', 'speed'),
      wind_direction: response.dig('wind', 'deg'),
      visibility: response.dig('visibility'),
      uv_index: response.dig('main', 'temp_max'), # UV index not available in current weather
      timestamp: Time.at(response['dt']).utc,
      location: {
        name: response['name'],
        country: response.dig('sys', 'country'),
        latitude: response.dig('coord', 'lat'),
        longitude: response.dig('coord', 'lon')
      }
    }
  end

  # Parses forecast API response into standardized format
  # @param response [Hash] Raw API response
  # @return [Hash] Standardized forecast data
  def parse_forecast_response(response)
    {
      location: {
        name: response['city']['name'],
        country: response['city']['country'],
        latitude: response['city']['coord']['lat'],
        longitude: response['city']['coord']['lon']
      },
      daily_forecasts: group_forecasts_by_day(response['list'])
    }
  end

  # Groups hourly forecasts into daily summaries
  # @param forecast_list [Array] List of hourly forecasts
  # @return [Array] Array of daily forecast summaries
  def group_forecasts_by_day(forecast_list)
    daily_forecasts = {}
    
    forecast_list.each do |forecast|
      date = Time.at(forecast['dt']).to_date
      
      unless daily_forecasts[date]
        daily_forecasts[date] = {
          date: date,
          temperatures: [],
          descriptions: [],
          icons: [],
          humidity: [],
          wind_speed: []
        }
      end
      
      daily_forecasts[date][:temperatures] << forecast.dig('main', 'temp')
      daily_forecasts[date][:descriptions] << forecast.dig('weather', 0, 'description')
      daily_forecasts[date][:icons] << forecast.dig('weather', 0, 'icon')
      daily_forecasts[date][:humidity] << forecast.dig('main', 'humidity')
      daily_forecasts[date][:wind_speed] << forecast.dig('wind', 'speed')
    end
    
    # Convert to array and calculate daily summaries
    daily_forecasts.values.map do |day_data|
      {
        date: day_data[:date],
        high: day_data[:temperatures].max.round(1),
        low: day_data[:temperatures].min.round(1),
        description: most_common(day_data[:descriptions]),
        icon: most_common(day_data[:icons]),
        humidity: (day_data[:humidity].sum / day_data[:humidity].size).round,
        wind_speed: (day_data[:wind_speed].sum / day_data[:wind_speed].size).round(1)
      }
    end.sort_by { |day| day[:date] }
  end

  # Finds the most common element in an array
  # @param array [Array] Array to analyze
  # @return [String] Most frequently occurring element
  def most_common(array)
    array.group_by(&:itself).max_by { |_, group| group.size }&.first
  end
end
