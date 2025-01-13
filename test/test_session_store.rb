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
require "sbsm/session_store"
require "sbsm/validator"
require "sbsm/trans_handler"
require "sbsm/app"
require "rack"
require "rack/test"

begin
  require "pry"
rescue LoadError
end

class SBSM::Session
  attr_accessor :mtime
end

class SBSM::SessionStore
  CAP_MAX_THRESHOLD = 2
  MAX_SESSIONS = 3
end

class TestSessionStore < Minitest::Test
  include Rack::Test::Methods
  def setup
    @app = SBSM::App.new
    @session = SBSM::Session.new(app: @app)
    @session_store = SBSM::SessionStore.new(app: @app)
  end

  attr_reader :app

  IDS = ["1", "2", "3", "4", "5", "6", "7"]
  NR_SESSIONS = IDS.size
  def test_clean
    assert_equal(0, SBSM::SessionStore.sessions.size)
    IDS.each do |session_id|
      @session_store[session_id].mtime = Time.now - (SBSM::Session::EXPIRES + 2)
    end
    assert_equal(NR_SESSIONS, SBSM::SessionStore.sessions.size)
    @session_store.clean
    assert_equal(0, SBSM::SessionStore.sessions.size)
  end

  def test_session_store_clear
    IDS.each do |session_id|
      @session_store[session_id]
    end
    assert_equal(NR_SESSIONS, SBSM::SessionStore.sessions.size)
    SBSM::SessionStore.clear
    assert_equal(0, SBSM::SessionStore.sessions.size)
  end

  def test_session_cap_max_session
    IDS.each do |session_id|
      @session_store[session_id]
    end
    assert_equal(NR_SESSIONS, SBSM::SessionStore.sessions.size)
    @session_store.cap_max_sessions
    assert_equal(2, NR_SESSIONS - SBSM::SessionStore::CAP_MAX_THRESHOLD - SBSM::SessionStore::MAX_SESSIONS)
    assert_equal(2 + 1, SBSM::SessionStore.sessions.size)
  end
end
