#!/usr/bin/env ruby

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

require "minitest/autorun"
require "sbsm/session"
require "sbsm/validator"
require "sbsm/trans_handler"
require "sbsm/app"
require "rack"
require "rack/test"

begin
  require "pry"
rescue LoadError
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
  def reset_errors
  end

  def validate(key, value, mandatory = false)
    value
  end

  def valid_values(key)
    if key == "foo"
      ["foo", "bar"]
    end
  end

  def error?
    false
  end
end

class StubSessionRequest < Rack::Request
  def initialize(path = "", params = {})
    super(Rack::MockRequest.env_for("http://example.com:8080/#{path}", params))
  end
end

class StubSessionView
  def initialize(foo, bar)
  end

  def http_headers
    {"foo" => "bar"}
  end

  def to_html(context)
    "0123456789" * 3
  end
end

class StubSessionBarState < SBSM::State
  EVENT_MAP = {
    foobar: StubSessionBarState
  }
end

class StubSessionBarfoosState < SBSM::State
  DIRECT_EVENT = :barfoos
end

class StubSessionFooState < SBSM::State
  EVENT_MAP = {
    bar: StubSessionBarState
  }
end

class StubSessionState < SBSM::State
  VIEW = StubSessionView
  attr_accessor :volatile
  def foo
    @foo ||= StubSessionFooState.new(@session, @model)
  end
end

class StubVolatileState < SBSM::State
  VOLATILE = true
end

class StubSessionWithView < SBSM::Session
  DEFAULT_STATE = StubSessionState
  CAP_MAX_THRESHOLD = 3
  MAX_STATES = 3
  DEFAULT_FLAVOR = "gcc"
  attr_accessor :user, :state
  attr_accessor :attended_states, :cached_states, :cookie_input
  attr_writer :lookandfeel, :persistent_user_input
  attr_writer :active_state
  public :active_state
  def initialize(*args, **kwargs)
    kwargs[:app] ||= StubSessionApp.new
    kwargs[:validator] ||= StubSessionValidator.new
    super
  end
end

class StubSessionSession < SBSM::Session
  attr_accessor :lookandfeel
  attr_writer :persistent_user_input
  DEFAULT_FLAVOR = "gcc"
  LF_FACTORY = {
    "gcc"	=>	"ccg",
    "sbb"	=>	"bbs"
  }
  def initialize(app:)
    super(app: app, validator: StubSessionValidator.new)
  end

  def persistent_user_input(key)
    super
  end
end

class TestSession < Minitest::Test
  include Rack::Test::Methods
  def setup
    @app = StubSessionApp.new(validator: StubSessionValidator.new)
    @session = StubSessionWithView.new(app: @app, validator: StubSessionValidator.new)
    @request = StubSessionRequest.new
    @state = StubSessionState.new(@session, nil)
  end

  attr_reader :app

  def test_cookies
    by_persistent_name = "63488f94c90813200f29e1a60de9a479ad52e71758f48e612e9f6390f80c7b7c"
    @session.cookie_input = {"remember" => "63488f94c90813200f29e1a60de9a479ad52e71758f48e612e9f6390f80c7b7c",
               "name" => "juerg@davaz.com",
               "language" => "en"}
    @request.cookies[:remember] = "my_remember_value"
    @request.cookies[:language] = "en"
    @request.cookies["_session_id"] = "10e524151d7f0da819f4222ecc1"
    @request.cookies[@session.persistent_cookie_name] = @session.cookie_pairs
    @session.cookie_input = {}
    assert_equal({}, @session.cookie_input)
    assert_nil(@session.persistent_user_input(:language))
    @session.process_rack(rack_request: @request)
    assert_equal([:remember, :name, :language], @session.cookie_input.keys)
    assert_equal("en", @session.cookie_input[:language])
    assert_equal(by_persistent_name, @session.cookie_input[:remember])
  end

  def test_cookie_pairs
    @session.cookie_input = {"name_last" => "Müller", "name_first" => "Cécile",
                              "nil_value" => nil, "empty_string" => "",
                              "boolean_true" => true,
                              "boolean_false" => false}
    assert_equal("name_last=M%C3%BCller;name_first=C%C3%A9cile;nil_value=;empty_string=;boolean_true=true;boolean_false=", @session.cookie_pairs)
    @request.cookies[@session.persistent_cookie_name] = @session.cookie_pairs
    @session.cookie_input = {}
    assert_equal({}, @session.cookie_input)
    @session.process_rack(rack_request: @request)
    assert_equal([:name_last, :name_first, :nil_value, :empty_string, :boolean_true, :boolean_false], @session.cookie_input.keys)
    assert_equal("Müller", @session.cookie_input[:name_last])
    assert_equal("Cécile", @session.cookie_input[:name_first])
    assert_equal("true", @session.cookie_input[:boolean_true])
    assert_equal("", @session.cookie_input[:nil_value])
    assert_equal("", @session.cookie_input[:empty_string])
    assert_equal("", @session.cookie_input[:boolean_false])
  end
end
