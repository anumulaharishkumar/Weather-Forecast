# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeocodingService, type: :service do
  let(:service) { described_class.new }
  let(:address) { 'New York, NY' }
  let(:latitude) { 40.7128 }
  let(:longitude) { -74.0060 }

  describe '#initialize' do
    it 'sets default cache duration' do
      expect(service.instance_variable_get(:@cache_duration)).to eq(GeocodingService::CACHE_DURATION)
    end

    it 'accepts custom cache duration' do
      custom_duration = 1.hour
      service = described_class.new(custom_duration)
      expect(service.instance_variable_get(:@cache_duration)).to eq(custom_duration)
    end
  end

  describe '#geocode_address' do
    let(:mock_result) do
      double('geocoder_result',
        latitude: latitude,
        longitude: longitude,
        address: 'New York, NY, USA',
        city: 'New York',
        state: 'NY',
        country: 'US',
        postal_code: '10001'
      )
    end

    before do
      allow(Geocoder).to receive(:search).with(address).and_return([mock_result])
    end

    it 'returns geocoding result' do
      result = service.geocode_address(address)
      
      expect(result[:latitude]).to eq(latitude)
      expect(result[:longitude]).to eq(longitude)
      expect(result[:address]).to eq('New York, NY, USA')
      expect(result[:city]).to eq('New York')
      expect(result[:state]).to eq('NY')
      expect(result[:country]).to eq('US')
      expect(result[:postal_code]).to eq('10001')
    end

    it 'caches the result' do
      expect(Rails.cache).to receive(:fetch).with(
        "geocode:#{address.downcase.strip}",
        expires_in: GeocodingService::CACHE_DURATION
      )
      
      service.geocode_address(address)
    end

    it 'returns error for blank address' do
      result = service.geocode_address('')
      expect(result[:error]).to eq('Address cannot be blank')
    end

    it 'returns error for nil address' do
      result = service.geocode_address(nil)
      expect(result[:error]).to eq('Address cannot be blank')
    end

    it 'handles geocoding errors' do
      allow(Geocoder).to receive(:search).and_raise(Geocoder::Error.new('Geocoding failed'))
      
      expect { service.geocode_address(address) }.to raise_error(StandardError, /Geocoding failed/)
    end

    it 'handles no results' do
      allow(Geocoder).to receive(:search).and_return([])
      
      expect { service.geocode_address(address) }.to raise_error(StandardError, /No results found/)
    end
  end

  describe '#valid_address?' do
    it 'returns true for valid addresses' do
      expect(service.valid_address?('New York, NY')).to be true
      expect(service.valid_address?('123 Main St, City, State')).to be true
      expect(service.valid_address?('London, UK')).to be true
    end

    it 'returns false for invalid addresses' do
      expect(service.valid_address?('')).to be false
      expect(service.valid_address?(nil)).to be false
      expect(service.valid_address?('ab')).to be false
      expect(service.valid_address?('123')).to be false
    end
  end

  describe '#reverse_geocode' do
    let(:mock_result) do
      double('geocoder_result',
        address: 'New York, NY, USA',
        city: 'New York',
        state: 'NY',
        country: 'US',
        postal_code: '10001'
      )
    end

    before do
      allow(Geocoder).to receive(:search).with([latitude, longitude]).and_return([mock_result])
    end

    it 'returns reverse geocoding result' do
      result = service.reverse_geocode(latitude, longitude)
      
      expect(result[:latitude]).to eq(latitude)
      expect(result[:longitude]).to eq(longitude)
      expect(result[:address]).to eq('New York, NY, USA')
      expect(result[:city]).to eq('New York')
    end

    it 'caches the result' do
      expect(Rails.cache).to receive(:fetch).with(
        "reverse_geocode:#{latitude}:#{longitude}",
        expires_in: GeocodingService::CACHE_DURATION
      )
      
      service.reverse_geocode(latitude, longitude)
    end

    it 'returns error for invalid coordinates' do
      result = service.reverse_geocode(200, 200)
      expect(result[:error]).to eq('Invalid coordinates')
    end

    it 'handles reverse geocoding errors' do
      allow(Geocoder).to receive(:search).and_raise(Geocoder::Error.new('Reverse geocoding failed'))
      
      expect { service.reverse_geocode(latitude, longitude) }.to raise_error(StandardError, /Reverse geocoding failed/)
    end
  end

  describe '#valid_coordinates?' do
    it 'returns true for valid coordinates' do
      expect(service.send(:valid_coordinates?, 40.7128, -74.0060)).to be true
      expect(service.send(:valid_coordinates?, 0, 0)).to be true
      expect(service.send(:valid_coordinates?, -90, -180)).to be true
      expect(service.send(:valid_coordinates?, 90, 180)).to be true
    end

    it 'returns false for invalid coordinates' do
      expect(service.send(:valid_coordinates?, 91, 0)).to be false
      expect(service.send(:valid_coordinates?, -91, 0)).to be false
      expect(service.send(:valid_coordinates?, 0, 181)).to be false
      expect(service.send(:valid_coordinates?, 0, -181)).to be false
      expect(service.send(:valid_coordinates?, 'invalid', 0)).to be false
      expect(service.send(:valid_coordinates?, 0, 'invalid')).to be false
    end
  end

  describe '#format_address' do
    let(:result) do
      double('geocoder_result',
        city: 'New York',
        state: 'NY',
        country: 'US',
        address: 'New York, NY, USA'
      )
    end

    it 'formats address with city, state, country' do
      formatted = service.send(:format_address, result)
      expect(formatted).to eq('New York, NY, US')
    end

    it 'falls back to full address when components are missing' do
      allow(result).to receive(:city).and_return(nil)
      allow(result).to receive(:state).and_return(nil)
      allow(result).to receive(:country).and_return(nil)
      
      formatted = service.send(:format_address, result)
      expect(formatted).to eq('New York, NY, USA')
    end
  end
end
