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
    # @app = Demo::SimpleSBSM.new(cookie_name: TEST_COOKIE_NAME)
    @app = Demo::SimpleRackInterface.new
  end
  def test_post_feedback
    get '/de/page' do # needed to set cookie
      last_response.set_cookie(TEST_COOKIE_NAME, :value =>  Hash.new('anrede' => 'value2'))
    end
    clear_cookies
    set_cookie 'anrede=value2'
    set_cookie "_session_id=#{TEST_COOKIE_NAME}"
    get '/de/page/feedback' do
    end
    assert_equal  ["_session_id", 'anrede'], last_request.cookies.keys
    expected = {"_session_id"=>"test-cookie", "anrede"=>"value2"}
    assert_equal expected, last_request.cookies
    assert_equal 'value2',  @app.last_session.persistent_user_input('anrede')
  end
end if RUN_ALL_TESTS

class AppTestSimple < Minitest::Test
  include Rack::Test::Methods
  attr_reader :app

  def setup
    @app = Demo::SimpleRackInterface.new
  end
  def test_session_redirect
    get '/de/page/redirect'
    assert_equal 303,last_response.status
    assert_equal 'feedback',last_response.headers['Location']
    assert_match REDIRECT_HTML_CONTENT, last_response.body
    assert_match /utf-8/i, last_response.headers['Content-Type']
  end if RUN_ALL_TESTS
  def test_post_feedback
    set_cookie "_session_id=#{TEST_COOKIE_NAME}"
    set_cookie "#{SBSM::Session::PERSISTENT_COOKIE_NAME}=dummy"
    get '/de/page/feedback' do
    end
    # assert_match /anrede.*=.*value2/, CGI.unescape(last_response.headers['Set-Cookie'])
    assert last_response.ok?
    assert_equal  ["_session_id", SBSM::Session::PERSISTENT_COOKIE_NAME], last_request.cookies.keys
    assert_equal(FEEDBACK_HTML_CONTENT, last_response.body)

    set_cookie "anrede=Herr"
    post '/de/page/feedback', { anrede: 'Herr',  msg: 'SBSM rocks!',  state_id: '1245'} do
    end
    page = Nokogiri::HTML(last_response.body)
    puts page.text
    binding.pry
    assert  page.css('input').find{|x| x.attributes['name'].value.eql?('state_id') }.attributes['value'].value
    state_id = page.css('input').find{|x| x.attributes['name'].value.eql?('state_id') }.attributes['value'].value.to_i
    assert state_id > 0
    post '/de/page/feedback', { 'anrede' => 'Herr', 'msg' => 'SBSM rocks!' , 'state_id' => '1245'}
    assert last_response.ok?
    assert last_response.headers['Content-Length'].to_s.length > 0
    assert_match CONFIRM_HTML_CONTENT, last_response.body
    post '/de/page/feedback', { 'confirm' => 'true', 'anrede' => 'Herr', 'msg' => 'SBSM rocks!' }
    assert last_response.ok?
    assert_match CONFIRM_DONE_HTML_CONTENT, last_response.body
  end
if RUN_ALL_TESTS
  def test_session_home
    get '/home'
    assert last_response.ok?
    assert_match /^request_path is \/home$/, last_response.body
    assert_match HOME_HTML_CONTENT, last_response.body
    assert_match /utf-8/i, last_response.headers['Content-Type']
  end

  def test_session_redirect
    get '/de/page/redirect'
    assert_equal 303,last_response.status
    assert_equal 'feedback',last_response.headers['Location']
    assert_match REDIRECT_HTML_CONTENT, last_response.body
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
end
  def test_session_home_then_fr_about
    puts 888
    get '/home'
    assert last_response.ok?
    assert_match /^request_path is \/home$/, last_response.body
    assert_match HOME_HTML_CONTENT, last_response.body
    get '/fr/page/about'
    assert last_response.ok?
    assert_match ABOUT_HTML_CONTENT, last_response.body
  end
end