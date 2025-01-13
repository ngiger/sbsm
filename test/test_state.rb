#!/usr/bin/env ruby

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
# TestState -- oddb -- 20.11.2002 -- hwyss@ywesee.com

$: << File.dirname(__FILE__)
$: << File.expand_path("../lib", File.dirname(__FILE__))

require "minitest/autorun"
require "sbsm/state"

class StubStateState1
  attr_accessor :previous
  def initialize(*args)
  end

  def reset_view
  end
end

class StubStateState2
  attr_accessor :previous
  def initialize(*args)
  end

  def reset_view
  end
end

class StubStateState3
  attr_accessor :previous
  def initialize(*args)
  end

  def reset_view
  end
end

class StubStateView
  attr_reader :model, :session, :http_headers
  def initialize(model, session)
    @model, @session = model, session
  end
end

class StubStateUserView < StubStateView
end

class StubStateUser
end

class StubStateSession
  def user
    :test_default
  end
end

class StubStateUserSession
  def user
    StubStateUser.new
  end
end

class State < SBSM::State
  attr_reader :init_called
  attr_writer :errors, :session, :filter, :warnings
  DIRECT_EVENT = :foo
  EVENT_MAP = {
    bar: StubStateState1
  }
  GLOBAL_MAP = {
    baz: StubStateState2
  }
  VIEW = StubStateView
  def himself
    self
  end

  def buc
    StubStateState3.new
  end

  def init
    @init_called = true
  end
end

class UserState < State
  VIEW = {
    :default	=>	StubStateView,
    StubStateUser	=>	StubStateUserView
  }
end

class TestState < Minitest::Test
  def setup
    @state = State.new(nil, nil)
  end

  def test_direct_event
    assert_equal(:foo, State.direct_event)
  end

  def test_trigger_default
    assert_equal(@state, @state.trigger(:foo))
  end

  def test_trigger_event
    assert_equal(StubStateState1, @state.trigger(:bar).class)
  end

  def test_trigger_global
    assert_equal(StubStateState2, @state.trigger(:baz).class)
  end

  def test_trigger_method
    assert_equal(StubStateState3, @state.trigger(:buc).class)
  end

  def test_errors
    assert_equal(false, @state.error?)
    @state.errors = {de: "ein Error"}
    assert_equal(true, @state.error?)
    assert_equal("ein Error", @state.error(:de))
    new_state = @state.trigger(:himself)
    assert_equal(@state, new_state)
    assert_equal(false, @state.error?)
  end

  def test_default
    assert_respond_to(@state, :default)
  end

  def test_warnings
    assert_equal(false, @state.warning?)
    warning = SBSM::Warning.new("eine Warnung", :foo, "")
    @state.warnings = [warning]
    assert_equal(true, @state.warning?)
    assert_equal(warning, @state.warning(:foo))
    new_state = @state.trigger(:himself)
    assert_equal(@state, new_state)
    assert_equal(false, @state.warning?)
    @state.add_warning("A Message", "key", "A Value")
    assert_equal(true, @state.warning?)
    assert_equal(1, @state.warnings.size)
    warning = @state.warnings.first
    assert_equal(warning, @state.warning(:key))
    assert_instance_of(SBSM::Warning, warning)
    assert_equal("A Message", warning.message)
    assert_equal(:key, warning.key)
    assert_equal("A Value", warning.value)
    @state.add_warning("Another Message", :key2, "Another Value")
    assert_equal(2, @state.warnings.size)
  end
end

class TestUserState < Minitest::Test
  def test_no_user_view_defined
    state = State.new(StubStateSession.new, nil)
    assert_equal(StubStateView, state.view.class)
  end

  def test_default_user_view
    state = UserState.new(StubStateSession.new, nil)
    assert_equal(StubStateView, state.view.class)
  end

  def test_user_view
    state = UserState.new(StubStateUserSession.new, nil)
    assert_equal(StubStateUserView, state.view.class)
  end

  def test_filtered_view
    model = [1, 2, 3, 4, 5]
    state = UserState.new(StubStateSession.new, model)
    state.filter = proc { |model|
      model.select { |entry| entry > 2 }
    }
    view = state.view
    assert_equal(3, view.model.size)
  end
end
