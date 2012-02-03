require 'rack'
require 'rack/cache/cachecontrol'

module Rack

  class MockResponse < Rack::Response
      
    def cached?
      cache_control['public'] == true &&
       cache_control['max-age'] &&
       cache_control['max-age'].to_i > 0
    end

    def has_max_age?(seconds)
      cache_control['max-age'] == seconds.to_s
    end

    def has_cache_control_public?
      cache_control['public'] == true
    end

    private

    def cache_control
      @cache_control ||= Rack::Cache::CacheControl.new(headers['Cache-Control'])
    end

  end

end
