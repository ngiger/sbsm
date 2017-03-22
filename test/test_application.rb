#!/usr/bin/env ruby
# encoding: utf-8
$: << File.dirname(__FILE__)
$:.unshift File.expand_path('../lib', File.dirname(__FILE__))

ENV['RACK_ENV'] = 'test'
ENV['REQUEST_METHOD'] = 'GET'

require 'minitest/autorun'
require 'rack/test'
require 'sbsm/app'
require 'sbsm/session'
require 'simple_sbsm'
require 'nokogiri'

RUN_ALL_TESTS=true unless defined?(RUN_ALL_TESTS)

# Here we test, whether setting various class constant have the desired effect

class AppVariantTest < Minitest::Test
  include Rack::Test::Methods
  attr_reader :app
  def setup
    @app = Demo::SimpleRackInterface.new
  end
  def test_persistent_user_input_language
    clear_cookies
    set_cookie "_session_id=#{TEST_COOKIE_NAME}"
    get '/fr/page/feedback' do end
    assert_equal  ["_session_id"], last_request.cookies.keys
    expected = {"_session_id"=>"test-cookie", }
    assert_equal expected, last_request.cookies
    assert_equal 'fr',  @app.last_session.persistent_user_input('language')
  end if RUN_ALL_TESTS

  def test_post_feedback
    clear_cookies
    state_id = 12345
    set_cookie "_session_id=#{TEST_COOKIE_NAME}"
    get '/fr/page/feedback' do end
    puts "after get #{last_request.cookies}"
    assert_equal 'fr',  @app.last_session.persistent_user_input('language')
    m = /VALUE=[^\d]+(\d+)/.match(last_response.body.to_s)
    new_state_id = m[1]
    puts "new_state_id after get changed #{state_id} to #{new_state_id}"
# email=test%40test.org&anrede=&name=&vorname=&firma=&adresse=&ort=&telefon=&bestell_diss=&bestell_pedi=&confirm=Weiter&text=Mein+Feedback&flavor=&language=en&event=confirm&state_id=70106191393460
    post '/de/page/feedback', { anrede: 'Herr',  msg: 'SBSM rocks!',  state_id: new_state_id} do
    end
    puts "after post #{last_request.cookies}"
    m = /VALUE=[^\d]+(\d+)/.match(last_response.body.to_s)
    state_id_after_post = m[1]
    puts "state_id_after_post is #{state_id_after_post}"
    page = Nokogiri::HTML(last_response.body)
    assert_equal 'Herr',  @app.last_session.persistent_user_input('anrede')
    assert(state_id != @app.last_session.persistent_user_input('state_id'))
    assert(state_id_after_post != @app.last_session.persistent_user_input('state_id'))
    # assert_nil @app.last_session.persistent_user_input('msg')

    skip('post feedback test does not yet work correctly')
    assert_match(CONFIRM_HTML_CONTENT, last_response.body)
    post '/de/page/feedback', { 'confirm' => 'true', 'anrede' => 'Herr', 'msg' => 'SBSM rocks!' }
    assert last_response.ok?
    assert_match CONFIRM_DONE_HTML_CONTENT, last_response.body
  end
end

class AppTestSimple < Minitest::Test
  include Rack::Test::Methods
  attr_reader :app

  def setup
    @app = Demo::SimpleRackInterface.new
  end
if RUN_ALL_TESTS
  def test_post_feedback
    set_cookie "_session_id=#{TEST_COOKIE_NAME}"
    set_cookie "#{SBSM::Session::PERSISTENT_COOKIE_NAME}=dummy"
    get '/de/page/feedback' do
    end
    # assert_match /anrede.*=.*value2/, CGI.unescape(last_response.headers['Set-Cookie'])
    assert last_response.ok?
    assert_equal  ["_session_id", SBSM::Session::PERSISTENT_COOKIE_NAME], last_request.cookies.keys
    assert_match(FEEDBACK_HTML_CONTENT, last_response.body)

    set_cookie "anrede=Herr"
    post '/de/page/feedback', { anrede: 'Herr',  msg: 'SBSM rocks!',  state_id: '1245'} do
    end
    post '/de/page/feedback', { 'anrede' => 'Herr', 'msg' => 'SBSM rocks!' , 'state_id' => '1245'}
    assert last_response.ok?
    assert last_response.headers['Content-Length'].to_s.length > 0
    skip('post feedback test does not yet work correctly')
    assert_match CONFIRM_HTML_CONTENT, last_response.body
    post '/de/page/feedback', { 'confirm' => 'true', 'anrede' => 'Herr', 'msg' => 'SBSM rocks!' }
    assert last_response.ok?
    assert_match CONFIRM_DONE_HTML_CONTENT, last_response.body
  end
  def test_session_home
    get '/home'
    assert last_response.ok?
    assert_match /^request_path is \/home$/, last_response.body
    assert_match HOME_HTML_CONTENT, last_response.body
    assert_match /utf-8/i, last_response.headers['Content-Type']
  end

  def test_css_file
    css_content = "html { max-width: 960px; margin: 0 auto; }"
    css_file = File.join('doc/sbsm.css')
    FileUtils.makedirs(File.dirname(css_file))
    unless File.exist?(css_file)
      File.open(css_file, 'w+') do |file|
        file.puts css_content
      end
    end
    get '/sbsm.css'
    assert last_response.ok?
    assert_match css_content, last_response.body
  end
  def test_session_about_then_home
    get '/de/page/about'
    assert last_response.ok?
    assert_match /^About SBSM: TDD ist great!/, last_response.body
    get '/de/page/home'
    assert last_response.ok?
    assert_match HOME_HTML_CONTENT, last_response.body
  end
  def test_default_content_from_home
    test_path = '/default_if_no_such_path'
    get test_path
    assert last_response.ok?
    assert_match /^#{HOME_HTML_CONTENT}/, last_response.body
    assert_match HOME_HTML_CONTENT, last_response.body
    assert_match /^request_path is /, last_response.body
    assert_match test_path, last_response.body
  end
  def test_session_id_is_maintained
    get '/'
    assert last_response.ok?
    body = last_response.body.clone
    assert_match /^request_path is \/$/, body
    assert_match /member_counter is 1$/, body
    assert_match HOME_HTML_CONTENT, body
    # Getting the request a second time must increment the class, but not the member counter
    m = /class_counter is (\d+)$/.match(body)
    counter = m[1]
    assert_match /class_counter is (\d+)$/, body
    get '/'
    assert last_response.ok?
    body = last_response.body.clone
    assert_match /^request_path is \/$/, body
    class_line = /class_counter.*/.match(body)[0]
    assert_match /class_counter is #{counter.to_i+1}$/, class_line
    member_line = /member_counter.*/.match(body)[0]
    assert_match /member_counter is 1$/, member_line
  end
  def test_session_home_then_fr_about
    get '/home'
    assert last_response.ok?
    assert_match /^request_path is \/home$/, last_response.body
    assert_match HOME_HTML_CONTENT, last_response.body
    get '/fr/page/about'
    assert last_response.ok?
    assert_match ABOUT_HTML_CONTENT, last_response.body
  end

  def test_session_home_then_fr_about
    get '/home'
    assert last_response.ok?
    assert_match /^request_path is \/home$/, last_response.body
    assert_match HOME_HTML_CONTENT, last_response.body
    get '/fr/page/about'
    assert last_response.ok?
    assert_match ABOUT_HTML_CONTENT, last_response.body
  end
  def test_session_about_then_root
    get '/fr/page/about'
    assert last_response.ok?
    assert_match ABOUT_HTML_CONTENT, last_response.body
    get '/'
    assert last_response.ok?
    assert_match HOME_HTML_CONTENT, last_response.body
  end

  def test_show_stats
    # We add it here to get some more or less useful statistics
    ::SBSM::Session.show_stats '/de/page'
  end if RUN_ALL_TESTS
  def test_session_home_then_fr_about
    puts 888
    get '/home'
    assert last_response.ok?
    assert_match /^request_path is \/home$/, last_response.body
    assert_match HOME_HTML_CONTENT, last_response.body
    get '/fr/page/about'
    assert last_response.ok?
    assert_match ABOUT_HTML_CONTENT, last_response.body
  end  if RUN_ALL_TESTS
end
end