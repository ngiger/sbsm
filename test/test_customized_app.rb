#!/usr/bin/env ruby
# encoding: utf-8
$: << File.dirname(__FILE__)
$:.unshift File.expand_path('../lib', File.dirname(__FILE__))
require 'minitest/autorun'
require 'rack/test'
require 'sbsm/app'
require 'sbsm/session'
require 'nokogiri'
require 'sbsm/state'
require 'simple_sbsm'

ENV['RACK_ENV'] = 'test'
ENV['REQUEST_METHOD'] = 'GET'
RUN_ALL_TESTS=true unless defined?(RUN_ALL_TESTS)

# Overriding some stuff from the simple_sbsm
module Demo
  class AboutState < GlobalState
    DIRECT_EVENT = :about
    def initialize(session, user)
      SBSM.info "AboutState #{session}"
      super(session, user)
      session.login
    end
    def http_headers
      { "foo" =>  "bar" }
    end
  end


  DEMO_PERSISTENT_COOKIE_NAME = 'demo-simple-sbsm'
  class Demo::CustomizedSBSM_COOKIE < SBSM::App
    PERSISTENT_COOKIE_NAME = DEMO_PERSISTENT_COOKIE_NAME
  end

  class CustomLookandfeel < SBSM::Lookandfeel
    LANGUAGES = ['fr']

    DICTIONARIES = {
      'fr' => {
        hello:              'Bonjour'
              }
    }
  end

  class CustomizedValidator < SBSM::Validator
    def initialize
      SBSM.debug "CustomizedValidator init"
      @@visited_init = true
      super
    end

    def self.get_visited_init
      defined?(@@visited_init) ? @@visited_init : :not_initialized
    end
  end

  class CustomizedSession < SBSM::Session
    DEFAULT_STATE           = AboutState
    SERVER_NAME            = 'custom_server'
    DEFAULT_ZONE           = :custome_zone
    DEFAULT_LANGUAGE       = 'fr'
    PERSISTENT_COOKIE_NAME = 'CustomizedSession-cookie'
    LOOKANDFEEL            = CustomLookandfeel

    def initialize(args)
      SBSM.debug "session args #{args}"
      @@active_stated_visited = false
      @@login_visited = false
      @@visited_init = true
      super(args)
    end

    def flavor
      SBSM.info 'test-flavor'
      'test-flavor'
    end

    def active_state
      SBSM.info '@active_stated_visited'
      @@active_stated_visited = true
      @active_state = super
    end

    def flavor
      SBSM.info 'test-flavor'
      'test-flavor'
    end

    def login
     @@login_visited = true
     SBSM.info "@login_visited from #{@request_path}"
     'user'
    end

    def self.get_visited_init
      defined?(@@visited_init) ? @@visited_init : :not_initialized
    end

    def self.get_visited_active_state
      defined?(@@active_stated_visited) ? @@active_stated_visited : :not_initialized
    end

    def self.get_visited_login
      defined?(@@login_visited) ? @@login_visited : :not_initialized
    end
  end
  class CustomizedSBSM < SBSM::App
    def initialize
      SBSM.info "CustomizedSBSM.new"
    end
  end

  class CustomizedRackInterface < SBSM::RackInterface
    SESSION = CustomizedSession

    def initialize(validator: CustomizedValidator.new,
                   trans_handler: SBSM::TransHandler.instance,
                   cookie_name: nil,
                   session_class: SESSION)
      SBSM.info "CustomizedRackInterface.new SESSION #{SESSION}"
      super(app: CustomizedSBSM.new,
            validator: validator,
            trans_handler: trans_handler,
            cookie_name: cookie_name,
            session_class: session_class)
    end
  end

end

class CustomizedAppInvalidValidator < Minitest::Test
  include Rack::Test::Methods
  attr_reader :app

  def test_raise_exeption_if_class
    @app = Demo::CustomizedRackInterface.new(validator: ::SBSM::Validator)
    assert_raises {  get '/' do   end }
  end

  def test_valid_if_validator
    @app = Demo::CustomizedRackInterface.new(validator: ::SBSM::Validator.new)
    get '/' do   end
  end
end if RUN_ALL_TESTS

class CustomizedAppInvalidTranshandler < Minitest::Test
  include Rack::Test::Methods
  attr_reader :app

  def test_raise_exeption_if_class
    @app = Demo::CustomizedRackInterface.new(trans_handler: ::SBSM::TransHandler)
    assert_raises {  get '/' do   end }
  end

  def test_valid_if_validator_instance
    @app = Demo::CustomizedRackInterface.new(trans_handler: ::SBSM::TransHandler.instance)
    get '/' do   end
  end
end if RUN_ALL_TESTS

class CustomizedAppSessionValidatorLnf < Minitest::Test
  include Rack::Test::Methods
  attr_reader :app
  def setup
    @app = Demo::CustomizedRackInterface.new
  end

  def test_customized_active_state
    get '/' do
    end
    assert last_response.ok?
    assert_equal true, Demo::CustomizedSession.get_visited_active_state, 'Should have visited customized active_state'
  end if RUN_ALL_TESTS
  def test_customized_session_init
    get '/' do
    end
    assert last_response.ok?
    assert_equal true, Demo::CustomizedSession.get_visited_init, 'Should have visited customized session init'
  end if RUN_ALL_TESTS

  def test_customized_validator
    # @app = Demo::CustomizedSBSM.new(validator: Demo::CustomizedValidator.new)
    get '/' do
    end
    assert last_response.ok?
    assert_equal true, Demo::CustomizedValidator.get_visited_init, 'Should have initialized customized validator'
  end if RUN_ALL_TESTS

  def test_customized_login
    get '/fr/page/about' do  # we patched to force a login
    end
    assert last_response.ok?
    assert_equal true, Demo::CustomizedSession.get_visited_login, 'Should have visited customized login'
  end if RUN_ALL_TESTS

  def test_customized_http_header
    get '/fr/page/about' do  # we patched to force a login
    end
    assert last_response.ok?
    assert_equal 'bar', last_response.headers['foo']
  end if RUN_ALL_TESTS

  def test_process_state
    get '/fr/page/home' do  # we patched to force a login
    end
    assert_equal Demo::AboutState, @app.last_session.active_state.class
    assert_equal(1, @app.last_session.attended_states.size)
    get '/fr/page/feedback' do  # we patched to force a login
    end
    assert_equal(1, @app.last_session.attended_states.size)
    skip('test_process_state does not yet work correctly')
    assert_equal Demo::FeedbackState, @app.last_session.active_state.class
  end

  def test_customized_cookie_name
    my_cookey_name = 'my-cookie-name'
    @app = Demo::CustomizedRackInterface.new(cookie_name: my_cookey_name)
    get '/' do
    end
    assert last_response.ok?
    # TEST_COOKIE_NAME set via param to app
    cookie = last_response.get_header('Set-Cookie').split("\n").find_all{|x| x.index(my_cookey_name)}
    assert_equal 1, cookie.size
    assert_match my_cookey_name, cookie.first
  end if RUN_ALL_TESTS
end

class CustomizedAppCookieName < Minitest::Test
  include Rack::Test::Methods
  attr_reader :app
  def setup
    @sbsm_app = SBSM::App.new
    @app = SBSM::RackInterface.new(app: @sbsm_app, cookie_name: Demo::DEMO_PERSISTENT_COOKIE_NAME)
  end
  def test_customized_cookie_name
    get '/' do
    end
    assert last_response.ok?
    cookie = last_response.get_header('Set-Cookie').split("\n").find_all{|x| x.index(Demo::DEMO_PERSISTENT_COOKIE_NAME)}
    assert_equal 1, cookie.size
    assert_match Demo::DEMO_PERSISTENT_COOKIE_NAME, cookie.first
  end if RUN_ALL_TESTS
end

