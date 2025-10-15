# frozen_string_literal: true

# WeatherController handles weather forecast requests and responses
# This controller provides endpoints for retrieving weather data based on addresses
# and includes proper error handling, validation, and caching support
class WeatherController < ApplicationController
  before_action :validate_address, only: [:forecast]
  before_action :set_units, only: [:forecast]

  # GET /weather
  # Main weather forecast page with simple UI
  def index
    # This will render the index.html.erb view
  end

  # GET /weather/forecast
  # Retrieves weather forecast for a given address
  # @param address [String] Address to get weather for
  # @param units [String] Temperature units (metric, imperial, kelvin)
  # @return [JSON] Weather data including current conditions and forecast
  def forecast
    begin
      # Step 1: Geocode the address to get coordinates
      geocoding_result = geocode_address
      return render_error(geocoding_result[:error], :bad_request) if geocoding_result[:error]

      # Step 2: Get weather data using coordinates
      weather_data = fetch_weather_data(geocoding_result)
      
      # Step 3: Check if data came from cache
      weather_data[:cached] = data_from_cache?(geocoding_result)
      
      # Step 4: Add location information
      weather_data[:location] = geocoding_result
      
      render json: {
        success: true,
        data: weather_data,
        meta: {
          address: params[:address],
          units: @units,
          cached: weather_data[:cached],
          timestamp: Time.current
        }
      }
    rescue StandardError => e
      Rails.logger.error "Weather forecast error: #{e.message}"
      render_error("Unable to retrieve weather data: #{e.message}", :internal_server_error)
    end
  end

  # GET /weather/health
  # Health check endpoint for the weather service
  # @return [JSON] Service health status
  def health
    begin
      # Test geocoding service
      geocoding_service = GeocodingService.new
      geocoding_healthy = geocoding_service.valid_address?("New York, NY")
      
      # Test weather service (with a simple API call)
      weather_service = WeatherService.new
      weather_healthy = test_weather_api(weather_service)
      
      # Test cache
      cache_healthy = test_cache
      
      overall_health = geocoding_healthy && weather_healthy && cache_healthy
      
      render json: {
        status: overall_health ? 'healthy' : 'unhealthy',
        services: {
          geocoding: geocoding_healthy ? 'up' : 'down',
          weather_api: weather_healthy ? 'up' : 'down',
          cache: cache_healthy ? 'up' : 'down'
        },
        timestamp: Time.current
      }
    rescue StandardError => e
      render json: {
        status: 'unhealthy',
        error: e.message,
        timestamp: Time.current
      }, status: :service_unavailable
    end
  end

  private

  # Validates that the address parameter is present and valid
  # @return [void]
  def validate_address
    address = params[:address]
    
    if address.blank?
      render_error('Address parameter is required', :bad_request)
      return
    end
    
    unless GeocodingService.new.valid_address?(address)
      render_error('Invalid address format', :bad_request)
      return
    end
  end

  # Sets the temperature units for the request
  # @return [void]
  def set_units
    @units = params[:units] || 'metric'
    
    unless %w[metric imperial kelvin].include?(@units)
      render_error('Invalid units. Must be metric, imperial, or kelvin', :bad_request)
      return
    end
  end

  # Geocodes the provided address
  # @return [Hash] Geocoding result with coordinates and location details
  def geocode_address
    geocoding_service = GeocodingService.new
    geocoding_service.geocode_address(params[:address])
  end

  # Fetches weather data for the given coordinates
  # @param geocoding_result [Hash] Geocoding result containing coordinates
  # @return [Hash] Weather data including current conditions and forecast
  def fetch_weather_data(geocoding_result)
    weather_service = WeatherService.new
    weather_service.weather_data(
      geocoding_result[:latitude],
      geocoding_result[:longitude],
      @units,
      geocoding_result[:postal_code] # Pass postal code for zip code-based caching
    )
  end

  # Checks if the weather data was retrieved from cache
  # @param geocoding_result [Hash] Geocoding result containing coordinates
  # @return [Boolean] True if data came from cache
  def data_from_cache?(geocoding_result)
    # Use postal code for cache key if available, otherwise fall back to coordinates
    cache_identifier = geocoding_result[:postal_code] || "#{geocoding_result[:latitude]}:#{geocoding_result[:longitude]}"
    
    # Check if current weather data is in cache
    current_cache_key = "weather:current:#{cache_identifier}:#{@units}"
    forecast_cache_key = "weather:forecast:#{cache_identifier}:#{@units}"
    
    Rails.cache.exist?(current_cache_key) && Rails.cache.exist?(forecast_cache_key)
  end

  # Tests the weather API connectivity
  # @param weather_service [WeatherService] Weather service instance
  # @return [Boolean] True if API is accessible
  def test_weather_api(weather_service)
    # Use a known location for testing (New York City)
    weather_service.current_weather(40.7128, -74.0060, 'metric')
    true
  rescue StandardError
    false
  end

  # Tests the cache functionality
  # @return [Boolean] True if cache is working
  def test_cache
    test_key = "health_check:#{Time.current.to_i}"
    test_value = "test_#{rand(1000)}"
    
    Rails.cache.write(test_key, test_value, expires_in: 1.minute)
    cached_value = Rails.cache.read(test_key)
    
    cached_value == test_value
  rescue StandardError
    false
  end

  # Renders a standardized error response
  # @param message [String] Error message
  # @param status [Symbol] HTTP status code
  # @return [void]
  def render_error(message, status)
    render json: {
      success: false,
      error: message,
      timestamp: Time.current
    }, status: status
  end
end
