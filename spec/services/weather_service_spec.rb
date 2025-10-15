# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeatherService, type: :service do
  let(:api_key) { 'test_api_key' }
  let(:service) { described_class.new(api_key) }
  let(:latitude) { 40.7128 }
  let(:longitude) { -74.0060 }
  let(:units) { 'metric' }

  describe '#initialize' do
    it 'sets the API key and base URL' do
      expect(service.instance_variable_get(:@api_key)).to eq(api_key)
      expect(service.instance_variable_get(:@base_url)).to eq(WeatherService::BASE_URL)
    end

    it 'uses default values when not provided' do
      service = described_class.new
      expect(service.instance_variable_get(:@api_key)).to eq(Rails.application.config.openweather_api_key)
    end
  end

  describe '#current_weather' do
    let(:mock_response) do
      {
        'main' => {
          'temp' => 22.5,
          'feels_like' => 24.0,
          'humidity' => 65,
          'pressure' => 1013
        },
        'weather' => [{
          'description' => 'clear sky',
          'icon' => '01d'
        }],
        'wind' => {
          'speed' => 3.5,
          'deg' => 180
        },
        'visibility' => 10000,
        'dt' => Time.current.to_i,
        'name' => 'New York',
        'sys' => { 'country' => 'US' },
        'coord' => { 'lat' => latitude, 'lon' => longitude }
      }
    end

    before do
      allow(service).to receive(:make_api_request).and_return(mock_response)
    end

    it 'returns current weather data' do
      result = service.current_weather(latitude, longitude, units)
      
      expect(result[:temperature]).to eq(22.5)
      expect(result[:feels_like]).to eq(24.0)
      expect(result[:humidity]).to eq(65)
      expect(result[:description]).to eq('clear sky')
      expect(result[:location][:name]).to eq('New York')
    end

    it 'caches the result' do
      expect(Rails.cache).to receive(:fetch).with(
        "weather:current:#{latitude}:#{longitude}:#{units}",
        expires_in: service.instance_variable_get(:@cache_duration)
      )
      
      service.current_weather(latitude, longitude, units)
    end

    it 'handles API errors' do
      allow(service).to receive(:make_api_request).and_raise(StandardError, 'API Error')
      
      expect { service.current_weather(latitude, longitude, units) }.to raise_error(StandardError, 'API Error')
    end
  end

  describe '#forecast' do
    let(:mock_forecast_response) do
      {
        'city' => {
          'name' => 'New York',
          'country' => 'US',
          'coord' => { 'lat' => latitude, 'lon' => longitude }
        },
        'list' => [
          {
            'dt' => Time.current.to_i,
            'main' => { 'temp' => 22.0, 'humidity' => 60 },
            'weather' => [{ 'description' => 'clear sky', 'icon' => '01d' }],
            'wind' => { 'speed' => 3.0 }
          },
          {
            'dt' => (Time.current + 1.day).to_i,
            'main' => { 'temp' => 25.0, 'humidity' => 70 },
            'weather' => [{ 'description' => 'partly cloudy', 'icon' => '02d' }],
            'wind' => { 'speed' => 4.0 }
          }
        ]
      }
    end

    before do
      allow(service).to receive(:make_api_request).and_return(mock_forecast_response)
    end

    it 'returns forecast data' do
      result = service.forecast(latitude, longitude, units)
      
      expect(result[:location][:name]).to eq('New York')
      expect(result[:daily_forecasts]).to be_an(Array)
      expect(result[:daily_forecasts].first).to have_key(:date)
      expect(result[:daily_forecasts].first).to have_key(:high)
      expect(result[:daily_forecasts].first).to have_key(:low)
    end

    it 'caches the result' do
      expect(Rails.cache).to receive(:fetch).with(
        "weather:forecast:#{latitude}:#{longitude}:#{units}",
        expires_in: service.instance_variable_get(:@cache_duration)
      )
      
      service.forecast(latitude, longitude, units)
    end
  end

  describe '#weather_data' do
    let(:current_weather) { { temperature: 22.5, description: 'clear sky' } }
    let(:forecast) { { daily_forecasts: [] } }

    before do
      allow(service).to receive(:current_weather).and_return(current_weather)
      allow(service).to receive(:forecast).and_return(forecast)
    end

    it 'combines current weather and forecast data' do
      result = service.weather_data(latitude, longitude, units)
      
      expect(result[:current]).to eq(current_weather)
      expect(result[:forecast]).to eq(forecast)
      expect(result[:cached]).to be false
    end
  end

  describe '#make_api_request' do
    let(:endpoint) { 'weather' }
    let(:params) { { lat: latitude, lon: longitude, units: units, appid: api_key } }
    let(:mock_response) { double('response', success?: true, parsed_response: { 'main' => { 'temp' => 22.5 } }) }

    before do
      allow(service.class).to receive(:get).and_return(mock_response)
    end

    it 'makes HTTP request with correct parameters' do
      expect(service.class).to receive(:get).with(
        "#{WeatherService::BASE_URL}/#{endpoint}",
        query: params
      )
      
      service.send(:make_api_request, endpoint, params)
    end

    it 'raises error for failed requests' do
      failed_response = double('response', success?: false, code: 401, parsed_response: { 'message' => 'Invalid API key' })
      allow(service.class).to receive(:get).and_return(failed_response)
      
      expect { service.send(:make_api_request, endpoint, params) }.to raise_error(StandardError, /Invalid API key/)
    end

    it 'handles network errors' do
      allow(service.class).to receive(:get).and_raise(HTTParty::Error.new('Network error'))
      
      expect { service.send(:make_api_request, endpoint, params) }.to raise_error(StandardError, /Network error/)
    end
  end

  describe '#parse_weather_response' do
    let(:response) do
      {
        'main' => { 'temp' => 22.5, 'feels_like' => 24.0, 'humidity' => 65, 'pressure' => 1013 },
        'weather' => [{ 'description' => 'clear sky', 'icon' => '01d' }],
        'wind' => { 'speed' => 3.5, 'deg' => 180 },
        'visibility' => 10000,
        'dt' => 1640995200,
        'name' => 'New York',
        'sys' => { 'country' => 'US' },
        'coord' => { 'lat' => 40.7128, 'lon' => -74.0060 }
      }
    end

    it 'parses weather response correctly' do
      result = service.send(:parse_weather_response, response)
      
      expect(result[:temperature]).to eq(22.5)
      expect(result[:feels_like]).to eq(24.0)
      expect(result[:humidity]).to eq(65)
      expect(result[:pressure]).to eq(1013)
      expect(result[:description]).to eq('clear sky')
      expect(result[:icon]).to eq('01d')
      expect(result[:wind_speed]).to eq(3.5)
      expect(result[:wind_direction]).to eq(180)
      expect(result[:visibility]).to eq(10000)
      expect(result[:location][:name]).to eq('New York')
      expect(result[:location][:country]).to eq('US')
    end
  end

  describe '#most_common' do
    it 'returns the most common element' do
      array = ['sunny', 'cloudy', 'sunny', 'rainy', 'sunny']
      result = service.send(:most_common, array)
      expect(result).to eq('sunny')
    end

    it 'handles empty array' do
      result = service.send(:most_common, [])
      expect(result).to be_nil
    end
  end
end
