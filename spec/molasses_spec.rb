require 'spec_helper'
require 'rack/mock'

describe "Rack::Molasses" do

  def mock_request(options={})
    app = lambda {|env| [200, {"Content-Type" => "text/plain"}, ["Hello World"]]}
    app = Rack::Molasses.new(app, options)
    Rack::MockRequest.new(app)
  end

  def mock_request_with_cache_control(cache_control, options={})
    headers = {"Content-Type" => "text/plain", 'Cache-Control' => cache_control}
    app = lambda {|env| [200, headers, ["Hello World"]]}
    app = Rack::Molasses.new(app, options)
    Rack::MockRequest.new(app)
  end

  DEFAULT_MAX_AGE = TestHelp::ONE_HOUR

  let(:cacheable_response) {
    mock_request(:cache_when_path_matches => /images/).get('/images/foo')
  }

  let(:uncacheable_response) {
    mock_request(:cache_when_path_matches => /images/).get('/some/path')
  }



  context 'side-effects' do
    specify 'should not change response body' do
      uncacheable_response.body.should == 'Hello World'
      cacheable_response.body.should == 'Hello World'
    end

    specify 'should not change response status' do
      uncacheable_response.status == 200
      cacheable_response.status == 200
    end

    specify 'should not change other headers' do
      uncacheable_response.headers['Content-Type'].should == 'text/plain'
      cacheable_response.headers['Content-Type'].should == 'text/plain'
    end
  end



  context 'default behavior' do
    specify 'should only cache get requests' do
      request = mock_request(:cache_when_path_matches => /images/)
      response = request.get('/images/foo')
      response.should be_cached
      response = request.post('/images/foo')
      response.should_not be_cached
      response = request.put('/images/foo')
      response.should_not be_cached
      response = request.delete('/images/foo')
      response.should_not be_cached
    end

    specify 'should set cache control to public when caching' do
      cacheable_response.should have_cache_control_public
    end

    specify 'should set max-age to one hour by default when caching' do
      cacheable_response.should have_max_age(TestHelp::ONE_HOUR)
    end

    specify 'should raise error if cache_when_path_matches is absent' do
      lambda { mock_request }.should raise_error(Rack::Molasses::Error)
    end
  end



  context 'path matching' do
    specify 'should cache when path matches regex' do
      request = mock_request(:cache_when_path_matches => /images/)
      response = request.get('/images/foo')
      response.should be_cached
      response = request.get('/image/foo')
      response.should_not be_cached
      request = mock_request(:cache_when_path_matches => /fred\-/)
      response = request.get('/alfred-the-butler')
      response.should be_cached
      response = request.get('/alf-the-butler')
      response.should_not be_cached
    end

    specify 'should cache when path starts with string' do
      request = mock_request(:cache_when_path_matches => '/images')
      response = request.get('/images/foo')
      response.should be_cached
      response = request.get('/image/foo')
      response.should_not be_cached
      request = mock_request(:cache_when_path_matches => 'fred')
      response = request.get('/alfred-the-butler')
      response.should_not be_cached
      response = request.get('/alf-the-butler')
      response.should_not be_cached
    end

    specify 'should cache when path matches one of the regexen' do
      request = mock_request(:cache_when_path_matches => [/images/, /stylesheets/])
      response = request.get('/images/foo')
      response.should be_cached
      response = request.get('/image/foo')
      response.should_not be_cached
      response = request.get('/bar/stylesheets/foo')
      response.should be_cached
      response = request.get('/bar/style/sheets/foo')
      response.should_not be_cached
    end

    specify 'should cache when path starts with one of the strings' do
      request = mock_request(:cache_when_path_matches => ['/foo', '/bar', '/baz'])
      response = request.get('/foo/images/fo.png')
      response.should be_cached
      response = request.get('/images/march')
      response.should_not be_cached
      response = request.get('/bar/stylesheets')
      response.should be_cached
      response = request.get('/baz')
      response.should be_cached
    end

    specify 'should cache when path matches one of the strings or regexen' do
      request = mock_request(:cache_when_path_matches => [/foo/, '/bar', 'baz'])
      response = request.get('/images/foo')
      response.should be_cached
      response = request.get('/images/march')
      response.should_not be_cached
      response = request.get('/bar/none')
      response.should be_cached
    end

    specify 'should raise an error if cache_when_path_matches is neither an array, string nor regex' do
      lambda do
        request = mock_request(:cache_when_path_matches => 7)
        response = request.get('/images/foo')
      end.should raise_error(Rack::Molasses::Error)
    end
  end



  context 'cache busters' do
    specify 'should recognize a date-based query string cache buster (Rails < 3.1)' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '30 seconds')
      response = request.get('/images/foo.png')
      response.should have_max_age(DEFAULT_MAX_AGE)
      response = request.get('/images/foo.png?6734897846')
      response.should have_max_age(30)
    end

    specify 'should recognize a file fingerprint cache buster (Rails 3.1+)' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '30 seconds')
      response = request.get('/images/foo.png')
      response.should have_max_age(DEFAULT_MAX_AGE)
      response = request.get('/images/foo-2ba81a47c5512d9e23c435c1f29373cb.png')
      response.should have_max_age(30)
      response = request.get('/images/foo-e19343e6c6c76f8f634a685eba7c0880648b1389.png')
      response.should have_max_age(30)
    end

    specify 'should not be tricked by things that look like cache busters' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '30 seconds')
      response = request.get('/images/foo.png?value=3487986534')
      response.should have_max_age(DEFAULT_MAX_AGE)
      response = request.get('/images/foo.png?2012')
      response.should have_max_age(DEFAULT_MAX_AGE)
      response = request.get('/images/foo-12302012.png')
      response.should have_max_age(DEFAULT_MAX_AGE)
      response = request.get('/images/foo-barbaz.png')
      response.should have_max_age(DEFAULT_MAX_AGE)
    end

    specify 'should use :when_cache_busters_absent_cache_for as default max-age value' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_absent_cache_for => '15 seconds')
      response = request.get('/images/foo.png')
      response.should have_max_age(15)
      response = request.get('/images/foo.png?1756489253')
      response.should have_max_age(15)
    end

    specify 'should be able to set different max-age values depending on whether cache busters are present' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '45 seconds',
                             :when_cache_busters_absent_cache_for => '15 seconds')
      response = request.get('/images/foo.png')
      response.should have_max_age(15)
      response = request.get('/images/foo.png?7845893467')
      response.should have_max_age(45)
      response = request.get('/images/foo-2ba81a47c5512d9e23c435c1f29373cb.png')
      response.should have_max_age(45)
    end

    specify 'should be able to set cache time in minutes' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '45 minutes',
                             :when_cache_busters_absent_cache_for => '15 minutes')
      response = request.get('/images/foo.png')
      response.should have_max_age(15 * TestHelp::ONE_MINUTE)
      response = request.get('/images/foo.png?7845893467')
      response.should have_max_age(45 * TestHelp::ONE_MINUTE)
    end

    specify 'should be able to set cache time in hours' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '45 hours',
                             :when_cache_busters_absent_cache_for => '15 hours')
      response = request.get('/images/foo.png')
      response.should have_max_age(15 * TestHelp::ONE_HOUR)
      response = request.get('/images/foo.png?7845893467')
      response.should have_max_age(45 * TestHelp::ONE_HOUR)
    end

    specify 'should be able to set cache time in days' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '45 days',
                             :when_cache_busters_absent_cache_for => '15 days')
      response = request.get('/images/foo.png')
      response.should have_max_age(15 * TestHelp::ONE_DAY)
      response = request.get('/images/foo.png?7845893467')
      response.should have_max_age(45 * TestHelp::ONE_DAY)
    end

    specify 'should be able to set cache time in weeks' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '45 weeks',
                             :when_cache_busters_absent_cache_for => '15 weeks')
      response = request.get('/images/foo.png')
      response.should have_max_age(15 * TestHelp::ONE_WEEK)
      response = request.get('/images/foo.png?7845893467')
      response.should have_max_age(45 * TestHelp::ONE_WEEK)
    end

    specify 'should be able to set cache time in months' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '4 months',
                             :when_cache_busters_absent_cache_for => '2 months')
      response = request.get('/images/foo.png')
      response.should have_max_age(2 * TestHelp::ONE_MONTH)
      response = request.get('/images/foo.png?7845893467')
      response.should have_max_age(4 * TestHelp::ONE_MONTH)
    end

    specify 'should be able to set cache time in years' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_present_cache_for => '1 year',
                             :when_cache_busters_absent_cache_for => '1 year')
      response = request.get('/images/foo.png')
      response.should have_max_age(TestHelp::ONE_YEAR)
      response = request.get('/images/foo.png?7845893467')
      response.should have_max_age(TestHelp::ONE_YEAR)
    end

    specify 'should not be able to set cache time longer than a year' do
      lambda do
        mock_request(:cache_when_path_matches => '/images',
                     :when_cache_busters_present_cache_for => '2 years',
                     :when_cache_busters_absent_cache_for => '1 month')
      end.should raise_error(Rack::Molasses::Error)
      lambda do
        mock_request(:cache_when_path_matches => '/images',
                     :when_cache_busters_present_cache_for => '2 days',
                     :when_cache_busters_absent_cache_for => '13 months')
      end.should raise_error(Rack::Molasses::Error)
    end

    specify 'should not be able to set a negative cache time' do
      lambda do
        mock_request(:cache_when_path_matches => '/images',
                     :when_cache_busters_present_cache_for => '-4 days',
                     :when_cache_busters_absent_cache_for => '1 month')
      end.should raise_error(Rack::Molasses::Error)
    end

    specify 'should be able to set a cache time to zero' do
      request = mock_request(:cache_when_path_matches => '/images',
                             :when_cache_busters_absent_cache_for => '0 seconds')
      response = request.get('/images/foo.png')
      response.should have_max_age(0)
    end
  end



  context 'existing cache control settings' do
    specify 'should not change any cache-control values if private is already set' do
      request = mock_request_with_cache_control('private', :cache_when_path_matches => '/images')
      response = request.get('/images/foo.png')
      response.headers['Cache-Control'].should == 'private'
      request = mock_request_with_cache_control('private, max-age=400, must-revalidate', :cache_when_path_matches => '/images')
      response = request.get('/images/foo.png')
      response.headers['Cache-Control'].should == 'private, max-age=400, must-revalidate'
    end

    specify 'should not change any cache-control values if no-store is already set' do
      request = mock_request_with_cache_control('no-store', :cache_when_path_matches => '/images')
      response = request.get('/images/foo.png')
      response.headers['Cache-Control'].should == 'no-store'
    end

    specify 'should not change any cache-control values if max-age is already set' do
      request = mock_request_with_cache_control('max-age=4500', :cache_when_path_matches => '/images')
      response = request.get('/images/foo.png')
      response.headers['Cache-Control'].should == 'max-age=4500'
      request = mock_request_with_cache_control('max-age=400, must-revalidate', :cache_when_path_matches => '/images')
      response = request.get('/images/foo.png')
      response.headers['Cache-Control'].should == 'max-age=400, must-revalidate'
    end
  end



end
