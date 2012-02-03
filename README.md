# Rack::Molasses



## Purpose

If your Rails application is deployed to a server that you don't manage (like
Heroku), then you don't have the ability to set up server-side caching (like
Varnish).

Fortunately, you can use Rack::Cache in your Rails middleware stack to
implement server-side caching.  Unfortunately, Rails does not set the
Cache-Control header when it serves up static assets (like your JavaScript,
CSS and image files).  This means that Rack::Cache and users' browsers will
never cache these static assets.

Rack::Molasses adds the appropriate Cache-Control header for these static
assets so that they will actually get cached.



## Basic Usage

Place the middleware in config.ru:

    use Rack::Molasses, :cache_when_path_matches => '/public'

Since Rack::Molasses doesn't actually read the static assets from disk, it
doesn't know which HTTP responses represent static assets.  So you have to
tell Rack::Molasses which request paths are for static assets.  The above code
example will cache any request whose path begins with "/public", such as
"/public/images/molasses.png" or "/public/disaster.html".

You can check the request path against multiple strings:

    use Rack::Molasses, :cache_when_path_matches => ['/images', '/javascripts', '/stylesheets']

You don't have to stick to strings; you can use regular expressions:

    use Rack::Molasses, :cache_when_path_matches => [/.+\.(png|css|js)$/]

You can specify different caching times for assets that have cache busters:

    use Rack::Molasses, :cache_when_path_matches => '/public',
                        :when_cache_busters_present_cache_for => '3 months',
                        :when_cache_busters_absent_cache_for => '12 hours'

Rack::Molasses only works with Ruby 1.9.



## Details

### Defaults

If the HTTP request is not a GET request, Rack::Molasses will not do anything.

If you do not specify any cache times, Rack::Molasses will by default set the
max-age to one hour (3600).

### Path Matching

The string or regex that you give to :cache_when_path_matches is compared
against the PATH_INFO variable, which is the part of the URL after the
domain and not including query parameters.  Consider the following URL:

    http://en.wikipedia.org/w/index.php?title=Boston_Molasses_Disaster&action=edit

The PATH_INFO would be

    /w/index.php

You should assume that the leading slash will always be in the PATH_INFO.

You can pass as many strings or regexen to :cache_when_path_matches as you
want.

### Cache-Busters

Rails 3.1 introduced a cache-busting strategy called fingerprinting.  Consider
the asset disaster.css.  Rails (via Sprockets) will compute a hash of the
file's contents and rename the file to
disaster-908e25f4bf641868d8683022a5b62f54.css

Earlier versions of Rails would use the file's last modified timestamp as the
query string like this:  disaster.css?1287643654

The request path for these assets will change whenever the assets get
redeployed.  This "busts the cache" since caches will think they are serving up
a completely different file than before the redeploy.  This means it's safe to
tell browsers that they can cache these assets as long as they want.

However, if you have any assets that do not have cache-busters, you shouldn't
cache them for too long since a redeploy will not invalidate any caches.
For example, if you use the image_tag helper, Rails will generate a
cache-buster for you, but if you code the img tag yourself, you won't have a
cache-buster.

So Rack::Molasses gives you a way to specify two different cache times
depending on whether it detects the presence of a Rails-style cache-buster:

    use Rack::Molasses, :cache_when_path_matches => '/public',
                        :when_cache_busters_present_cache_for => '1 year',
                        :when_cache_busters_absent_cache_for => '3 days'

If you only specify :when_cache_busters_present_cache_for, when there are no
cache-busters the default value of one hour will be used.

If you only specify :when_cache_busters_absent_cache_for, the cache time that
you use will be used in all cases (it will override the default of one hour).

The cache time is a string that consists of a number and units.  The
number must not be negative but can be zero.  Acceptable units are seconds,
minutes, hours, days, weeks, months and years.  Note that a "month" is
approximate (30 days) and a "year" is also approximate (365 days).  You
cannot specify a time longer than 1 year (365 days).

### What Rack::Molasses Does To The Cache-Control

Rails uses ActionDispatch::Static to serve up static assets.  It, in turn,
uses Rack::File.  Rack::File sets the "Last-Modified" header to the file's
timestamp, but this is not enough for the file to be cached.  You also need
to set either an "Expires" header or a "max-age" value in the "Cache-Control"
header.  In addition, if you are using Rack::Cache with Rails, Rack::Cache
will conservatively set the "Cache-Control" to private for these static assets
when users are logged in.  That's because Rack::Cache is assuming that some of
the static assets might be personal data that should never be cached.

Rack::Molasses sets the Cache-Control to "public" for all requests that match
:cache_when_path_matches.  This means that you shouldn't use Rack::Molasses if
some of your asset files are too private to be stored in a cache (such as a
browser cache after a user has logged out).

Rack::Molasses also sets the "max-age" value in the Cache-Control header.  The
combination of having Cache-Control set to "public" and having a "max-age"
means that both Rack::Cache and your users' browsers will cache these assets.

If Rack::Molasses detects that the Cache-Control header has already been set
to "private", that it has "no-store" set, or that it already has a "max-age"
value, then Rack::Molasses will not do anything.  It assumes that there is
some other middleware involved that already intelligently set the
Cache-Control header.

### Using With Rack::Cache

You don't have to use Rack::Cache to benefit from Rack::Molasses.  If you use
Rack::Molasses by itself, users' browsers will be able to cache assets.  But
if you also use Rack::Cache, you'll be able to cache assets on the server
side as well.  Just make sure that Rack::Molasses is after Rack::Cache in your
middleware stack.
