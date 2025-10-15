#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple test script to verify the weather forecast application
# This script can be run to test the application without a web browser

require 'net/http'
require 'json'
require 'uri'

class WeatherAppTester
  BASE_URL = 'http://localhost:3000'
  
  def initialize
    @base_url = BASE_URL
  end

  def test_health_endpoint
    puts "🔍 Testing health endpoint..."
    begin
      response = make_request('/weather/health')
      if response['status'] == 'healthy'
        puts "✅ Health check passed - All services are up"
        puts "   Services: #{response['services']}"
      else
        puts "❌ Health check failed - Some services are down"
        puts "   Services: #{response['services']}"
      end
    rescue => e
      puts "❌ Health check failed with error: #{e.message}"
    end
  end

  def test_forecast_endpoint(address = 'New York, NY', units = 'metric')
    puts "\n🌤️  Testing forecast endpoint..."
    puts "   Address: #{address}"
    puts "   Units: #{units}"
    
    begin
      params = {
        address: address,
        units: units
      }
      
      response = make_request('/weather/forecast', params)
      
      if response['success']
        puts "✅ Forecast request successful"
        display_weather_data(response['data'])
        puts "   Cached: #{response['meta']['cached'] ? 'Yes' : 'No'}"
        puts "   Timestamp: #{response['meta']['timestamp']}"
      else
        puts "❌ Forecast request failed: #{response['error']}"
      end
    rescue => e
      puts "❌ Forecast request failed with error: #{e.message}"
    end
  end

  def test_invalid_requests
    puts "\n🚫 Testing invalid requests..."
    
    # Test missing address
    puts "   Testing missing address..."
    begin
      response = make_request('/weather/forecast', { units: 'metric' })
      if response['success'] == false
        puts "✅ Correctly rejected missing address"
      else
        puts "❌ Should have rejected missing address"
      end
    rescue => e
      puts "❌ Error testing missing address: #{e.message}"
    end

    # Test invalid units
    puts "   Testing invalid units..."
    begin
      response = make_request('/weather/forecast', { address: 'New York, NY', units: 'invalid' })
      if response['success'] == false
        puts "✅ Correctly rejected invalid units"
      else
        puts "❌ Should have rejected invalid units"
      end
    rescue => e
      puts "❌ Error testing invalid units: #{e.message}"
    end
  end

  def test_caching
    puts "\n💾 Testing caching behavior..."
    
    # First request (should not be cached)
    puts "   First request (should not be cached)..."
    response1 = make_request('/weather/forecast', { address: 'London, UK', units: 'metric' })
    cached1 = response1.dig('meta', 'cached') || false
    puts "   Cached: #{cached1 ? 'Yes' : 'No'}"
    
    # Second request (should be cached)
    puts "   Second request (should be cached)..."
    sleep(1) # Small delay to ensure different timestamps
    response2 = make_request('/weather/forecast', { address: 'London, UK', units: 'metric' })
    cached2 = response2.dig('meta', 'cached') || false
    puts "   Cached: #{cached2 ? 'Yes' : 'No'}"
    
    if cached2 && !cached1
      puts "✅ Caching working correctly"
    else
      puts "⚠️  Caching behavior unexpected (this might be normal in development)"
    end
  end

  def test_different_units
    puts "\n🌡️  Testing different temperature units..."
    
    units_to_test = ['metric', 'imperial', 'kelvin']
    
    units_to_test.each do |units|
      puts "   Testing #{units} units..."
      begin
        response = make_request('/weather/forecast', { address: 'Paris, France', units: units })
        if response['success']
          temp = response.dig('data', 'current', 'temperature')
          puts "   Temperature: #{temp}° (#{get_unit_symbol(units)})"
        else
          puts "   Failed: #{response['error']}"
        end
      rescue => e
        puts "   Error: #{e.message}"
      end
    end
  end

  def run_all_tests
    puts "🚀 Starting Weather Forecast Application Tests"
    puts "=" * 50
    
    test_health_endpoint
    test_forecast_endpoint('New York, NY', 'metric')
    test_forecast_endpoint('Tokyo, Japan', 'imperial')
    test_invalid_requests
    test_caching
    test_different_units
    
    puts "\n" + "=" * 50
    puts "🏁 Test suite completed"
    puts "\nTo test the web interface, visit: http://localhost:3000"
  end

  private

  def make_request(path, params = {})
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?
    
    response = Net::HTTP.get_response(uri)
    
    if response.code.to_i >= 200 && response.code.to_i < 300
      JSON.parse(response.body)
    else
      { 'success' => false, 'error' => "HTTP #{response.code}: #{response.message}" }
    end
  rescue JSON::ParserError
    { 'success' => false, 'error' => 'Invalid JSON response' }
  rescue => e
    { 'success' => false, 'error' => e.message }
  end

  def display_weather_data(data)
    current = data['current']
    location = data['location']
    
    puts "   Location: #{location['formatted_address'] || location['address']}"
    puts "   Temperature: #{current['temperature']}°C"
    puts "   Description: #{current['description']}"
    puts "   Humidity: #{current['humidity']}%"
    puts "   Wind Speed: #{current['wind_speed']} m/s"
    
    if data['forecast'] && data['forecast']['daily_forecasts']
      puts "   Forecast: #{data['forecast']['daily_forecasts'].length} days available"
    end
  end

  def get_unit_symbol(units)
    case units
    when 'metric' then 'C'
    when 'imperial' then 'F'
    when 'kelvin' then 'K'
    else '?'
    end
  end
end

# Run the tests if this script is executed directly
if __FILE__ == $0
  tester = WeatherAppTester.new
  tester.run_all_tests
end
