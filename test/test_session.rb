#!/usr/bin/env ruby
# encoding: utf-8
#--
#
# State Based Session Management
# Copyright (C) 2004 Hannes Wyss
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# ywesee - intellectual capital connected, Winterthurerstrasse 52, CH-8006 Zürich, Switzerland
# hwyss@ywesee.com
#
# TestSession -- sbsm -- 22.10.2002 -- hwyss@ywesee.com 
#++

require 'minitest/autorun'
require 'sbsm/session'
require 'sbsm/validator'
require 'sbsm/trans_handler'
require 'sbsm/app'
require 'rack'
require 'rack/test'

begin
  require 'pry'
rescue LoadError
end

class StubSessionUnknownUser
end
class StubSessionSession < SBSM::Session
end
class StubSessionApp < SBSM::App
  attr_accessor :trans_handler, :validator
  SESSION = StubSessionSession
  def initialize(args = {})
    super()
  end
  def login(session)
    false
  end
  def async(&block)
    block.call
  end
end
class StubSessionValidator < SBSM::Validator
	def reset_errors; end
	def validate(key, value, mandatory=false)
		value
	end
	def valid_values(key)
		if(key=='foo')
			['foo', 'bar']
		end
	end
	def error?
		false
	end
end
class StubSessionRequest < Rack::Request
  def initialize(path='', params = {})
    super(Rack::MockRequest.env_for("http://example.com:8080/#{path}", params))
  end
end
class StubSessionView 
	def initialize(foo, bar)
	end
  def http_headers
    { "foo"   =>      "bar" }
  end
	def to_html(context)
		'0123456789' * 3
	end
end
class StubSessionBarState < SBSM::State
	EVENT_MAP = {
		:foobar	=>	StubSessionBarState,
	}
end	
class StubSessionBarfoosState < SBSM::State
	DIRECT_EVENT = :barfoos
end
class StubSessionFooState < SBSM::State
	EVENT_MAP = {
		:bar	=>	StubSessionBarState
	}
end
class StubSessionState < SBSM::State
	VIEW = StubSessionView
	attr_accessor :volatile
	def foo
		@foo ||= StubSessionFooState.new(@session,@model)
	end
end
class StubVolatileState < SBSM::State
	VOLATILE = true
end
class StubSessionWithView < SBSM::Session
	DEFAULT_STATE = StubSessionState
	CAP_MAX_THRESHOLD = 3
	MAX_STATES = 3
	DEFAULT_FLAVOR = 'gcc'
	attr_accessor :user, :state
	attr_accessor :attended_states, :cached_states
	attr_writer :lookandfeel, :persistent_user_input
	attr_writer :active_state
	public :active_state
  def initialize(args)
    args[:app]       ||= StubSessionApp.new
    args[:validator] ||= StubSessionValidator.new
    super(args)
    persistent_user_input = {}
  end
end
class StubSessionSession < SBSM::Session
	attr_accessor :lookandfeel
  attr_accessor :persistent_user_input
	DEFAULT_FLAVOR = 'gcc'
	LF_FACTORY = {
		'gcc'	=>	'ccg',
		'sbb'	=>	'bbs',
	}
	def initialize(app: app)
    super(app: app, validator:  StubSessionValidator.new)
		persistent_user_input = {}
	end
	def persistent_user_input(key)
		super
	end
end

class TestSession < Minitest::Test
  include Rack::Test::Methods
	def setup
    @app = StubSessionApp.new(validator: StubSessionValidator.new,
                           unknown_user: StubSessionUnknownUser.new)
    @session = StubSessionWithView.new(app: @app,
                           validator: StubSessionValidator.new,
                           unknown_user: StubSessionUnknownUser.new)
    @request = StubSessionRequest.new
		@state = StubSessionState.new(@session, nil)
	end

  def test_cookies
    c_name =  SBSM::Session::PERSISTENT_COOKIE_NAME
    c_value = "remember=63488f94c90813200f29e1a60de9a479ad52e71758f48e612e9f6390f80c7b7c\nname=juerg%40davaz.com\nlanguage=en"
    @request.cookies[:remember] = 'my_remember_value'
    @request.cookies[:language] = 'en'
    @request.cookies['_session_id'] = '10e524151d7f0da819f4222ecc1'
    @request.cookies[c_name] = 'my_cookie_id'
    @request.set_header('Set-Cookie', c_value)
    @session.process_rack(rack_request: @request)
    assert_equal([:remember, :language, :_session_id, c_name.to_sym], @session.cookie_input.keys)
    skip "Don't know how to test persistent_user_input"
    assert_equal('@session.valid_input', @session.persistent_user_input(:language))
    assert_equal('@session.valid_input', @session.valid_input)
  end
  def test_user_input
    @request["foo"] = "bar"
    @request["baz"] = "zuv"
    # next line checks whether we did setup correctly the session
    assert_equal(@session.validator.class, StubSessionValidator)
    @session.process_rack(rack_request: @request)
    assert_equal(['foo', 'bar'], @session.valid_values('foo'))
    assert_equal("zuv", @session.user_input(:baz))
    assert_equal("zuv", @session.user_input(:baz))
    result = @session.user_input(:foo, :baz)
    expected = {
      :foo  =>  'bar',
      :baz  =>  'zuv',
    }
    assert_equal(expected, result)
  end
  def test_persistent_user_input
    @request["baz"] = "zuv"
    @session.process_rack(rack_request: @request)
    assert_equal("zuv", @session.persistent_user_input(:baz))
    @session.process_rack(StubSessionRequest.new)
    assert_equal("zuv", @session.persistent_user_input(:baz))
    @request["baz"] = "bla"
    @session.process_rack(rack_request: @request)
    assert_equal("bla", @session.persistent_user_input(:baz))
  end
  def test_user_input_hash
    @request["hash[1]"] = "4"
    @request["hash[2]"] = "5"
    @request.params["hash[3]"] = "6"
    @request.params['real_hash'] = {'1' => 'a', '2' => 'b'}
    @session.process_rack(rack_request: @request)
    hash = @session.user_input(:hash)
    assert_equal(Hash, hash.class)
    assert_equal(3, hash.size)
    assert_equal("4", hash["1"])
    assert_equal("5", hash["2"])
    assert_equal("6", hash["3"])
    real_hash = @session.user_input(:real_hash)
    assert_equal(Hash, real_hash.class)
    assert_equal(2, real_hash.size)
    assert_equal("b", real_hash['2'])
  end
	def test_attended_states_store
		@session.process_rack(rack_request: @request)
		state = @session.state
		expected = {
			state.object_id => state
		}
		#puts 'test'
		#puts @state
		assert_equal(expected, @session.attended_states)
	end
	def test_attended_states_cap_max
		req1 = StubSessionRequest.new
		@session.process_rack(:rack_request =>req1)
		state1 = @session.state
		req2 = StubSessionRequest.new
		req2["event"] = "foo"	
		@session.process_rack(:rack_request =>req2)
		state2 = @session.state
		refute_equal(state1, state2)
		req3 = StubSessionRequest.new
		req3["event"] = :bar	
		@session.process_rack(:rack_request =>req3)
		state3 = @session.state
		refute_equal(state1, state3)
		refute_equal(state2, state3)
		attended = {
			state1.object_id => state1,
			state2.object_id => state2,
			state3.object_id => state3,
		}
		assert_equal(attended, @session.attended_states)
		req4 = StubSessionRequest.new
		req4["event"] = :foobar	
		@session.process_rack(:rack_request =>req4)
		@session.cap_max_states
		state4 = @session.state
		refute_equal(state1, state4)
		refute_equal(state2, state4)
		refute_equal(state3, state4)
		attended = {
			state2.object_id => state2,
			state3.object_id => state3,
			state4.object_id => state4,
		}
		assert_equal(attended, @session.attended_states)
	end
	def test_active_state1
		# Szenarien
		# - Keine State-Information in User-Input
		# - Unbekannter State in User-Input
		# - Bekannter State in User-Input

		state = StubSessionState.new(@session, nil)
		@session.attended_states = {
			state.object_id =>	state,
		}
		@session.active_state = @state
		assert_equal(@state, @session.active_state)
	end
	def test_active_state2
		# Szenarien
		# - Keine State-Information in User-Input
		# - Unbekannter State in User-Input
		# - Bekannter State in User-Input

		state = StubSessionState.new(@session, nil)
		@session.attended_states = {
			state.object_id =>	state,
		}
		@session.active_state = @state
		# @request.params.store('state_id', state.object_id.next)
		@session.process_rack(rack_request: @request)
		assert_equal(@state, @session.active_state)
	end
	def test_active_state3
		# Szenarien
		# - Keine State-Information in User-Input
		# - Unbekannter State in User-Input
		# - Bekannter State in User-Input

		state = StubSessionState.new(@session, nil)
		@session.attended_states = {
			state.object_id =>	state,
		}
		@session.state = @state
		@request.params.store('state_id', state.object_id)
		@session.process_rack(rack_request: @request)
		assert_equal(state.class, @session.active_state.class)
	end
	def test_volatile_state
		state = StubSessionState.new(@session, nil)
		volatile = StubVolatileState.new(@session, nil)
		state.volatile = volatile
		@session.active_state = state
		@session.state = state
		@request.params.store('event', :volatile)
		newstate = @session.process_rack(rack_request: @request)
		assert_equal(:volatile, @session.event)
		assert_equal(volatile, @session.state)
		assert_equal(state, @session.active_state)
		@request.params.store('event', :foo)
		newstate = @session.process_rack(rack_request: @request)
		assert_equal(state.foo, @session.state)
		assert_equal(state.foo, @session.active_state)
	end
  def test_cgi_compatible
    assert_respond_to(@session, :restore)
    assert_respond_to(@session, :update)
    assert_respond_to(@session, :close)
    assert_respond_to(@session, :delete)
  end
  def test_restore
    assert_instance_of(NilClass, @session.restore[:proxy])
  end
	def test_user_input_no_request
		assert_nil(@session.user_input(:no_input))
	end
	def test_user_input_nil
		@session.process_rack(rack_request: @request)
		assert_nil(@session.user_input(:no_input))
	end
  def test_user_input
		@request["foo"] = "bar"
		@request["baz"] = "zuv"
    @session.process_rack(rack_request: @request)
    assert_equal("bar", @session.user_input(:foo))
    assert_equal("zuv", @session.user_input(:baz))
    assert_equal("zuv", @session.user_input(:baz))
		result = @session.user_input(:foo, :baz)
		expected = {
			:foo	=>	'bar',
			:baz	=>	'zuv',
		}
		assert_equal(expected, result)
  end
	def test_user_input_hash
		@request["hash[1]"] = "4"
		@request["hash[2]"] = "5"
		@request["hash[3]"] = "6"
		@session.process_rack(rack_request: @request)
		hash = @session.user_input(:hash)
		assert_equal(Hash, hash.class)
		assert_equal(3, hash.size)
		assert_equal("4", hash["1"])
		assert_equal("5", hash["2"])
		assert_equal("6", hash["3"])
	end
	def test_http_protocol
		assert_equal("http", @session.http_protocol)
	end
	def test_login_fail_keep_user
		@session.login
		assert_equal(StubSessionUnknownUser, @session.user.class)
	end
	def test_logged_in
		assert_equal(StubSessionUnknownUser, @session.user.class)
		assert_equal(false, @session.logged_in?)
	end
	def test_valid_values
		assert_equal(['foo', 'bar'], @session.valid_values('foo'))
		assert_equal([], @session.valid_values('oof'))
	end
	def test_persistent_user_input
		@request["baz"] = "zuv"
    @session.process_rack(rack_request: @request)
		assert_equal("zuv", @session.persistent_user_input(:baz))
		@session.process_rack(rack_request: StubSessionRequest.new)
		assert_equal("zuv", @session.persistent_user_input(:baz))
		@request["baz"] = "bla"
    @session.process_rack(rack_request: @request)
		assert_equal("bla", @session.persistent_user_input(:baz))
	end
	def test_logout
		state = StubSessionBarState.new(@session, nil)
		@session.attended_states.store(state.object_id, state)
		assert_equal(state, @session.attended_states[state.object_id])
		@session.logout
		assert_equal(1, @session.attended_states.size)
	end
	def test_lookandfeel
		@session.lookandfeel=nil
		@session.persistent_user_input = {
			:flavor => 'some',
		}
		lnf = @session.lookandfeel
		assert_equal('gcc', @session.flavor)
		assert_equal('gcc', lnf.flavor)
		assert_instance_of(SBSM::Lookandfeel, lnf)
		lnf2 = @session.lookandfeel
    assert_equal('gcc', lnf2.flavor)
    assert_equal('en', lnf2.language)
    @session.persistent_user_input = {
			:flavor => 'other',
		}
		lnf3 = @session.lookandfeel
		assert_instance_of(SBSM::Lookandfeel, lnf)
    assert_equal('gcc', lnf3.flavor)
    assert_equal('en', lnf3.language) ## flavor does not change!
	end
	def test_lookandfeel2
    session = StubSessionSession.new(app: StubSessionApp.new)
		session.lookandfeel=nil
		session.persistent_user_input = {
			:flavor => 'gcc',
		}
		lnf = session.lookandfeel
		assert_equal('gcc', session.flavor)
	end
  def test_lookandfeel3
		session = StubSessionSession.new(app: StubSessionApp.new)
		session.lookandfeel=nil
		lnf2 = session.lookandfeel
		session.persistent_user_input = {
			:flavor => 'other',
		}
		assert_equal('gcc', session.flavor)
	end
end
