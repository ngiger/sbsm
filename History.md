# 1.6.4 / 13.01.2025

* Updated devenv environment for Ruby 3.4 (see https://devenv.sh/)
* Applied standard formatting using gem standard
* Cleanup all warnings/problem when running rake test
* Using markdown for History

# 1.6.3 / 07.01.2025

* Updated devenv environment for Ruby 3.3 (see https://devenv.sh/)
* Replace hpricot with nokogiri as hpricot is no longer maintained and leads to many test warnings under Ruby 3.4

# 1.6.2 / 25.01.2024

* Add devenv environment for Ruby 3.3 (see https://devenv.sh/)
* Replace Chronologger with Logger as https://github.com/ma2gedev/chrono_logger
  is no longer maintained and leads to test errors under Ruby 3.3
* Run all tests also under Ruby 3.3

# 1.6.1 / 09.12.2022

* Fix Mime-Bug for Davaz.com

# 1.6.0 / 13.06.2020

* Remove calls to obsolete taint/untaint methods

# 1.5.9 / 30.08.2017

* Fix recognition whether we are using HTTPS or not
* Fix using http_headers in views
* Allow non standard HTTP-Port

# 1.5.8 / 8.08.2017

* Fix recognizing mime type for unusual extensions

# 1.5.7 / 8.08.2017

* Return nice 404 error for non existing files

# 1.5.6 / 12.07.2017

* Handle several IPs in X_FORWARDED_FOR

# 1.5.5 / 12.07.2017

* Do not return body if HEAD is requested

# 1.5.4 / 11.07.2017

* Avoid nil error when rack_request is nil

# 1.5.3 / 05.07.2017

* Add process_late for ODDB.org limit_request
* Fix clearing/cap_max_state in sessionstore
* Delete some variable to save space in session_store

# 1.5.2 / 04.07.2017

* Fix handling true/false values in cookie

# 1.5.1 / 04.07.2017

* Return 302 if http_headers contain 'Location'

# 1.5.0 / 04.07.2017

* Correct handling nil/empty values in cookie
* Unescape cookie values before giving them back
* Fixed handling cookie_input

# 1.4.9 / 28.06.2017

* Fix is_crawler?

# 1.4.8 / 26.06.2017

* Fix setting mime_type for files like status/status_crawler

# 1.4.7 / 26.06.2017

* Set the debug logging level to WARN
* Allow retrieving the sessions from SessionStore

# 1.4.6 / 21.06.2017

* Added  SessionStore.clear
* Added reader unknown_user and session_store
* Admin server is now multi_threaded by default

# 1.4.5 / 13.06.2017

* Fix unknown_user if passing a class and not an instance of it
* Fix using pass_thru for oddb.org
* Fix setting unknown_user

# 1.4.4 / 12.06.2017

* Fix remote_ip for POST processing in xmlconf

# 1.4.3 / 06.06.2017

* Allow access to request_origin and request_params for POST processing in xmlconf
* Fix unit tests

# 1.4.2 / 23.05.2017

* Allow overriding http_protocol via ENV variable SERVER_PORT
* Return correct http_protocol https when serving on port 443

# 1.4.1 / 22.05.2017

* Moved _async from from SessionStore back to Session class

# 1.4.0 / 17.05.2017

* Moved _admin to separate AdminServer class

# 1.3.9 / 15.05.2017

* Added SBSM.warn and SBSM.error to make lib/sbsm/state.rb happy

# 1.3.8 / 15.05.2017

* Reverted some changes to make bbmb and virbac run

# 1.3.7 / 10.05.2017
* Some changes for VIRBAC which uses viral modules and a KnownUser class
** Add @server_name to rack session
** On logout we always set @user to SBSM::UnknownUser. There you cannot override it via parameter
* Moved _admin into separate class Admin_Server

# 1.3.6 / 21.3.2017
* Zeno wants a release when when we still have 10 failing unit tests
* Made SBSM multithreading optional. Defaults to off
* Answer with doc_root + '/index.html' if request-path is '/'
* Introduce RackInterface to separate concerns between SBSM::App which is member variable of the SBSM::Session
* An the RackInterface which is served as a Rack App object

# 1.3.5 /14.12.2016
* Refactored sbsm to work without DRb
* Added test/config.ru to be able to run tests via wrk
* The interface to Session.new changed and must be adapted by client where the SBSM::Session class is overridden.

# 1.3.4 /12.12.2016
* As we quite often got errors about recycled objects, I added a GC.start in the call method of sbsm/app
  It introduces a delay of 12 to 30 ms. Therefore we should look for a better solution later

# 1.3.3 / 7.12.2016
* Hashes are handled differently in mod_ruby and rack add a test for it, but I am unsure
  whether I handle everything is okay, as I had to add article to the STRINGS in davaz.compatible
  to make the app work again
** mod_ruby workedwith @request.params["hash[3]"] = "6"
** rack works like @request.params['real_hash'] = {'1' => 'a', '2' => 'b'}

# 1.3.2 / 15.11.2016
* Requires the drb_uri-parameter when creating an app
* Determine the MIME-Type of all returned files by their ending using gem mimemagic

# 1.3.1 / 9.11.2016
* Moved from mod_ruby to using webrick/rack interface
* Incompatible changes to 1.3.0 are that all trans_handlers must be fixed, as the parameters are
* changed now in the params field (to be compatible with Rack::Request). The SBSM::Request field notes has gone!
* See changes in steinwies.ch which were minimal
** Removed an unused require 'sbsm/request' in src/view/navbar.rb
** added a config.ru
** Changed Steinwies::App to derive from SBSM::App instead of SBSM::DRbServer and its initialize method
** The Session.initialize method had to pass a validator when calling super

* Open problems
** Handling redirects is not tested (and probably will not work)
** Handling passthru is not tested (and probably will not work)

# 1.3.0 / 08.08.2016
* Add a support to avoid offline mode by CGI.new in test purpose

# 1.2.9 / 20.07.2016
* Remove ARGV violation

# 1.2.8 / 09.06.2016
* As we need a DEFAULT_LANGUAGE and DEFAULT_FLAVOR they are forced to 'en', resp. 'sbsm'

# 1.2.7 / 10.05.2016

* Migration to Ruby 2.x works now
* Removed C-Interface
* Only Ruby >= 1.9 is supported

# 1.2.6 / 02.07.2014

* Revert "Tried migrating to ruby 2.1.2"
* Fix sbsm when being called from oddbd
* Put pry-debugger in separate Gemgroup
* Tried migrating to ruby 2.1.2

# 1.2.5 / 26.05.2014

* Use Mail instead of (outdated, last release in 2008) RMail for verification of e-mail addresses
* updated Rakefile so I can release the gem
Updated Manifest.txt
# 1.2.5 / 25.04.2016

* Made it suitable to work with ydim-html
* Port to Ruby 2.3.0. Removed dependency to rockit and hoe.
* Prepared for travis

# 1.2.5 / 25.11.2014

* Port to Ruby 2.1.2
* Prepared for travis

# 1.2.4 / 05.03.2014

* Many fixes by Niklaus Giger. See "git log"

# 1.2.3 / 10.12.2012

* Disallow unexpected methods call in validation

# 1.2.2 / 24.10.2012

* Fixed tainted path for File#expand_path

# 1.2.1 / 27.09.2012

* Fixed cgi loading problem on Production server

# 1.2.0 / 26.09.2012

*  Removed cookie.rb for error on production-server

# 1.1.9 / 26.09.2012

* Fixed bug in Cookie handling

# 1.1.8 / 15.05.2012

* Fixed encoding problem

# 1.1.7 / 15.05.2012

* Updated for http_headers in view
* Added default value of http_headers

# 1.1.6 / 28.04.2012

* Updated http_headers in state class

# 1.1.5 / 19.03.2012

* Re-allow windows user to first process

# 1.1.4 / 24.02.2012

* Skip the threads check process if status file is not found in the check of
* drb server threads

# 1.1.3 / 24.02.2012

* Drop crawler requests if drb server threads goes over 50

# 1.1.2 / 22.02.2012

* Added # -*- coding: ascii-8bit -*- to flavored_uri_parser.rb

# 1.1.1 / 22.02.2012

*  Removed CRAWLER_PATTERN constant from request.rb and used a local varible,
*  crawler_pattern, in Requst#is_crawler? method

# 1.1.0 / 20.02.2012

* Drop any request containing pointer in it.

# 1.0.9 / 20.02.2012

* Slow down greedy Windows-Clients.

# 1.0.8 / 19.02.2012

* Make greedy crawlers sleep for 2 seconds.

# 1.0.7 / 24.01.2012

* Fix untaint for trans_hander.rb

# 1.0.6 / 20.01.2012

* Added untaint to __FILE__ and request.server.document_root in trans_handler.rb
* this is to get rid of the Ruby 1.9.3*  error when mod_ruby is compiled against
* Ruby 1.9.3

	mod_ruby:
  	/usr/local/lib64/ruby/gems/1.9.1/gems/sbsm-1.0.5/lib/sbsm/trans_handler.rb:21:in
  	`expand_path': Insecure operation - expand_path (SecurityError)

# 1.0.5 / 17.01.2012

* Removed redefine_19_cookie.rb

# 1.0.4 / 16.01.2012

* Updated trans_handler.rb. If rockit library is not found, then simple_parse_uri method is used to parse uri.

# 1.0.3 / 22.12.2011

* Fix Date object loading error. Without this active agents and sequence data will not be saved in ch.oddb.org

# 1.0.2 / 09.12.2011

* Updated session.rb to be compatible for both Ruby 1.8 and 1.9.3-p0

# 1.0.1 / 08.12.2011

* Fix the number of argument error of DRbObject respond_to method

# 1.0.0 / 16.12.2010

* sbsm is now Ruby 1.9 ready.

  * Birthday!
