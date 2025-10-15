# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeatherController, type: :controller do
  let(:valid_address) { 'New York, NY' }
  let(:latitude) { 40.7128 }
  let(:longitude) { -74.0060 }
  let(:units) { 'metric' }

  describe 'GET #forecast' do
    let(:geocoding_result) do
      {
        latitude: latitude,
        longitude: longitude,
        address: 'New York, NY, USA',
        city: 'New York',
        state: 'NY',
        country: 'US',
        formatted_address: 'New York, NY, US'
      }
    end

    let(:weather_data) do
      {
        current: {
          temperature: 22.5,
          description: 'clear sky',
          humidity: 65,
          wind_speed: 3.5
        },
        forecast: {
          daily_forecasts: [
            { date: Date.current, high: 25.0, low: 18.0, description: 'sunny' }
          ]
        }
      }
    end

    before do
      allow_any_instance_of(GeocodingService).to receive(:geocode_address).and_return(geocoding_result)
      allow_any_instance_of(WeatherService).to receive(:weather_data).and_return(weather_data)
    end

    context 'with valid parameters' do
      it 'returns weather data successfully' do
        get :forecast, params: { address: valid_address, units: units }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['data']['current']['temperature']).to eq(22.5)
        expect(json_response['meta']['address']).to eq(valid_address)
        expect(json_response['meta']['units']).to eq(units)
      end

      it 'includes location information' do
        get :forecast, params: { address: valid_address, units: units }
        
        json_response = JSON.parse(response.body)
        expect(json_response['data']['location']['city']).to eq('New York')
        expect(json_response['data']['location']['state']).to eq('NY')
      end

      it 'handles different units' do
        get :forecast, params: { address: valid_address, units: 'imperial' }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']['units']).to eq('imperial')
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing address' do
        get :forecast, params: { units: units }
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Address parameter is required')
      end

      it 'returns error for blank address' do
        get :forecast, params: { address: '', units: units }
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Address parameter is required')
      end

      it 'returns error for invalid address format' do
        allow_any_instance_of(GeocodingService).to receive(:valid_address?).and_return(false)
        
        get :forecast, params: { address: 'ab', units: units }
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Invalid address format')
      end

      it 'returns error for invalid units' do
        get :forecast, params: { address: valid_address, units: 'invalid' }
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Invalid units. Must be metric, imperial, or kelvin')
      end
    end

    context 'when geocoding fails' do
      it 'returns error for geocoding failure' do
        allow_any_instance_of(GeocodingService).to receive(:geocode_address).and_return({ error: 'Geocoding failed' })
        
        get :forecast, params: { address: valid_address, units: units }
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Geocoding failed')
      end
    end

    context 'when weather service fails' do
      it 'returns error for weather service failure' do
        allow_any_instance_of(WeatherService).to receive(:weather_data).and_raise(StandardError, 'Weather API error')
        
        get :forecast, params: { address: valid_address, units: units }
        
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('Weather API error')
      end
    end

    context 'caching behavior' do
      it 'indicates when data comes from cache' do
        allow(controller).to receive(:data_from_cache?).and_return(true)
        
        get :forecast, params: { address: valid_address, units: units }
        
        json_response = JSON.parse(response.body)
        expect(json_response['data']['cached']).to be true
        expect(json_response['meta']['cached']).to be true
      end

      it 'indicates when data is fresh' do
        allow(controller).to receive(:data_from_cache?).and_return(false)
        
        get :forecast, params: { address: valid_address, units: units }
        
        json_response = JSON.parse(response.body)
        expect(json_response['data']['cached']).to be false
        expect(json_response['meta']['cached']).to be false
      end
    end
  end

  describe 'GET #health' do
    before do
      allow_any_instance_of(GeocodingService).to receive(:valid_address?).and_return(true)
      allow_any_instance_of(WeatherService).to receive(:current_weather).and_return({})
      allow(Rails.cache).to receive(:write).and_return(true)
      allow(Rails.cache).to receive(:read).and_return('test_value')
    end

    it 'returns healthy status when all services are up' do
      get :health
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('healthy')
      expect(json_response['services']['geocoding']).to eq('up')
      expect(json_response['services']['weather_api']).to eq('up')
      expect(json_response['services']['cache']).to eq('up')
    end

    it 'returns unhealthy status when geocoding fails' do
      allow_any_instance_of(GeocodingService).to receive(:valid_address?).and_return(false)
      
      get :health
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('unhealthy')
      expect(json_response['services']['geocoding']).to eq('down')
    end

    it 'returns unhealthy status when weather API fails' do
      allow_any_instance_of(WeatherService).to receive(:current_weather).and_raise(StandardError, 'API Error')
      
      get :health
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('unhealthy')
      expect(json_response['services']['weather_api']).to eq('down')
    end

    it 'returns unhealthy status when cache fails' do
      allow(Rails.cache).to receive(:write).and_raise(StandardError, 'Cache Error')
      
      get :health
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('unhealthy')
      expect(json_response['services']['cache']).to eq('down')
    end

    it 'handles general errors' do
      allow_any_instance_of(GeocodingService).to receive(:valid_address?).and_raise(StandardError, 'General Error')
      
      get :health
      
      expect(response).to have_http_status(:service_unavailable)
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('unhealthy')
      expect(json_response['error']).to eq('General Error')
    end
  end

  describe 'private methods' do
    describe '#validate_address' do
      it 'validates address parameter' do
        controller.params[:address] = valid_address
        allow(GeocodingService).to receive(:new).and_return(double(valid_address?: true))
        
        expect { controller.send(:validate_address) }.not_to raise_error
      end
    end

    describe '#set_units' do
      it 'sets default units to metric' do
        controller.params[:units] = nil
        controller.send(:set_units)
        expect(controller.instance_variable_get(:@units)).to eq('metric')
      end

      it 'validates units parameter' do
        controller.params[:units] = 'invalid'
        expect { controller.send(:set_units) }.to raise_error(ActionController::BadRequest)
      end
    end

    describe '#data_from_cache?' do
      it 'checks if data is in cache' do
        allow(Rails.cache).to receive(:exist?).and_return(true)
        geocoding_result = { latitude: latitude, longitude: longitude }
        
        result = controller.send(:data_from_cache?, geocoding_result)
        expect(result).to be true
      end
    end
  end
end
