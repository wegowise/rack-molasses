require 'rack/cache/cachecontrol'

module Rack

  class Molasses

    def initialize(app, options = {})
      @app = app
      @path_option = options[:cache_when_path_matches]
      if @path_option.nil?
        raise Rack::Molasses::Error.new('You must specify :cache_when_path_matches.')
      end
      if options[:when_cache_busters_present_cache_for]
        @cache_buster_present_seconds =
         TimeConverter.to_seconds(options[:when_cache_busters_present_cache_for])
        ensure_cache_time_not_too_large(@cache_buster_present_seconds)
      end
      if options[:when_cache_busters_absent_cache_for]
        @cache_buster_absent_seconds =
         TimeConverter.to_seconds(options[:when_cache_busters_absent_cache_for])
        ensure_cache_time_not_too_large(@cache_buster_absent_seconds)
      end
    end

    def call(env)
      @env = env
      @status, @headers, @body = @app.call(@env)
      add_cache_headers if should_cache?
      [@status, @headers, @body]
    end

    private

    def add_cache_headers
      cache_control = Rack::Cache::CacheControl.new(@headers['Cache-Control'])
      cache_control['public'] = true
      cache_control['max-age'] = determine_max_age
      @headers['Cache-Control'] = cache_control.to_s
    end

    def should_cache?
      return false unless @env['REQUEST_METHOD'] == 'GET'
      return false unless path_matches_options?
      cache_control = Rack::Cache::CacheControl.new(@headers['Cache-Control'])
      return false if cache_control.private?
      return false if cache_control.no_store?
      return false if cache_control.max_age
      true
    end

    def determine_max_age
      if @cache_buster_present_seconds && cache_buster_present?
        @cache_buster_present_seconds
      else
        @cache_buster_absent_seconds || 3600
      end
    end

    def cache_buster_present?
      @env['QUERY_STRING'] =~ /^\d{10}$/ ||
       @env['PATH_INFO'] =~ /.+\-[0-9a-f]{32,}\.(\w+)$/
    end

    def path_matches_options?
      path = @env['PATH_INFO']
      # ensure leading slash
      if path[0] != '/'
        path = '/' + path
      end
      if @path_option.is_a? Array
        for test in @path_option
          return true if path_matches?(path, test)
        end
        return false
      else
        path_matches?(path, @path_option)
      end
    end

    def path_matches?(path, test)
      if test.is_a? String
        path.start_with? test
      elsif test.is_a? Regexp
        test.match(path)
      else
        error_message = ':cache_when_path_matches expects a string, regex, '
        error_message << 'or an array of strings/regexen as its value.'
        raise Rack::Molasses::Error.new(error_message)
      end
    end

    def ensure_cache_time_not_too_large(seconds)
      approx_seconds_in_a_year = 3600 * 24 * 365
      if seconds > approx_seconds_in_a_year
        raise Rack::Molasses::Error.new('You cannot specify a cache time greater than a year.')
      end
    end

  end

end

