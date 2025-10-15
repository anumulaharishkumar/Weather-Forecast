# frozen_string_literal: true

require 'geocoder'

# GeocodingService handles address-to-coordinates conversion
# This service provides geocoding functionality using the Geocoder gem
# and includes caching to improve performance and reduce API calls
class GeocodingService
  # Cache duration for geocoding results (24 hours as addresses don't change often)
  CACHE_DURATION = 24.hours

  # Initialize the service with optional cache duration
  # @param cache_duration [ActiveSupport::Duration] How long to cache results
  def initialize(cache_duration = CACHE_DURATION)
    @cache_duration = cache_duration
  end

  # Converts an address string to latitude and longitude coordinates
  # @param address [String] Address to geocode (e.g., "New York, NY" or "123 Main St, City, State")
  # @return [Hash] Hash containing coordinates and location details
  # @raise [StandardError] If geocoding fails or address is invalid
  def geocode_address(address)
    return { error: 'Address cannot be blank' } if address.blank?

    # Fix common misspellings
    corrected_address = fix_common_misspellings(address)
    
    cache_key = "geocode:#{corrected_address.downcase.strip}"
    
    Rails.cache.fetch(cache_key, expires_in: @cache_duration) do
      perform_geocoding(corrected_address)
    end
  end

  # Validates if an address is valid without performing full geocoding
  # @param address [String] Address to validate
  # @return [Boolean] True if address appears valid, false otherwise
  def valid_address?(address)
    return false if address.blank?
    
    # Basic validation - address should have at least 3 characters
    # and contain some letters
    address.strip.length >= 3 && address.match?(/[a-zA-Z]/)
  end

  # Reverse geocoding - converts coordinates to address
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @return [Hash] Hash containing address details
  def reverse_geocode(latitude, longitude)
    return { error: 'Invalid coordinates' } unless valid_coordinates?(latitude, longitude)

    cache_key = "reverse_geocode:#{latitude}:#{longitude}"
    
    Rails.cache.fetch(cache_key, expires_in: @cache_duration) do
      perform_reverse_geocoding(latitude, longitude)
    end
  end

  private

  # Fixes common misspellings in city names
  # @param address [String] Original address
  # @return [String] Corrected address
  def fix_common_misspellings(address)
    corrections = {
      'hyderbad' => 'hyderabad',
      'banglore' => 'bangalore',
      'bengaluru' => 'bangalore',
      'bombay' => 'mumbai',
      'calcutta' => 'kolkata',
      'madras' => 'chennai',
      'prayagraj' => 'allahabad',
      'gurgaon' => 'gurugram',
      'mysore' => 'mysuru',
      'baroda' => 'vadodara',
      'trivandrum' => 'thiruvananthapuram',
      'cochin' => 'kochi',
      'calicut' => 'kozhikode',
      'mangalore' => 'mangaluru',
      'belgaum' => 'belagavi',
      'gulbarga' => 'kalaburagi',
      'hubli' => 'hubballi',
      'bellary' => 'ballari',
      'bijapur' => 'vijayapura',
      'shimoga' => 'shivamogga',
      'tumkur' => 'tumakuru',
      'chikmagalur' => 'chikkamagaluru',
      'kodagu' => 'coorg'
    }

    corrected = address.downcase.strip
    corrections.each do |misspelling, correction|
      corrected.gsub!(/\b#{misspelling}\b/, correction)
    end
    
    # If we made a correction, add a hint
    if corrected != address.downcase.strip
      Rails.logger.info "Geocoding: Corrected '#{address}' to '#{corrected}'"
    end
    
    corrected
  end

  # Performs the actual geocoding using the Geocoder gem
  # @param address [String] Address to geocode
  # @return [Hash] Geocoding result with coordinates and location details
  # @raise [StandardError] If geocoding fails
  def perform_geocoding(address)
    results = Geocoder.search(address)
    
    if results.empty?
      raise StandardError, "No results found for address: #{address}"
    end

    result = results.first
    
    {
      latitude: result.latitude,
      longitude: result.longitude,
      address: result.address,
      city: result.city,
      state: result.state,
      country: result.country,
      postal_code: result.postal_code,
      formatted_address: format_address(result)
    }
  rescue Geocoder::Error => e
    raise StandardError, "Geocoding error: #{e.message}"
  end

  # Performs reverse geocoding using the Geocoder gem
  # @param latitude [Float] Latitude coordinate
  # @param longitude [Float] Longitude coordinate
  # @return [Hash] Reverse geocoding result with address details
  # @raise [StandardError] If reverse geocoding fails
  def perform_reverse_geocoding(latitude, longitude)
    results = Geocoder.search([latitude, longitude])
    
    if results.empty?
      raise StandardError, "No results found for coordinates: #{latitude}, #{longitude}"
    end

    result = results.first
    
    {
      latitude: latitude,
      longitude: longitude,
      address: result.address,
      city: result.city,
      state: result.state,
      country: result.country,
      postal_code: result.postal_code,
      formatted_address: format_address(result)
    }
  rescue Geocoder::Error => e
    raise StandardError, "Reverse geocoding error: #{e.message}"
  end

  # Validates if coordinates are within valid ranges
  # @param latitude [Float] Latitude to validate
  # @param longitude [Float] Longitude to validate
  # @return [Boolean] True if coordinates are valid
  def valid_coordinates?(latitude, longitude)
    latitude.is_a?(Numeric) && longitude.is_a?(Numeric) &&
      latitude.between?(-90, 90) && longitude.between?(-180, 180)
  end

  # Formats a geocoding result into a readable address string
  # @param result [Geocoder::Result] Geocoding result object
  # @return [String] Formatted address string
  def format_address(result)
    parts = []
    parts << result.city if result.city.present?
    parts << result.state if result.state.present?
    parts << result.country if result.country.present?
    
    if parts.any?
      parts.join(', ')
    else
      result.address
    end
  end
end
