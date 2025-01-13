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
# SessionStore -- sbsm -- niger@ywesee.com
#  2016: ported this code from the old DrbServer
#++

require "delegate"
require "sbsm/session"
require "sbsm/user"
require "digest/md5"
require "sbsm/logger"
require "sbsm/validator"
require "sbsm/session_store"

module SBSM
  #
  # SessionStore manages session, which are kept in memory
  # Sessions are limited and expire after some time
  # The maximal amount of concurrent session is given via CAP_MAX_THRESHOLD
  #
  class SessionStore
    CLEANING_INTERVAL = 30
    CAP_MAX_THRESHOLD = 120
    MAX_SESSIONS = 100
    RUN_CLEANER = true
    SESSION = Session
    UNKNOWN_USER = UnknownUser
    VALIDATOR = nil
    attr_reader :cleaner, :updater, :persistence_layer
    @@mutex = Mutex.new
    @@sessions = {}
    def initialize(app:,
      persistence_layer: nil,
      trans_handler: nil,
      session_class: nil,
      validator: nil,
      cookie_name: nil,
      unknown_user: UNKNOWN_USER.new,
      multi_threaded: nil)
      fail "You must specify an app!" unless app
      @@sessions = {}
      @cleaner = run_cleaner if self.class.const_get(:RUN_CLEANER)
      @app = app
      @system = persistence_layer
      @persistence_layer = persistence_layer
      @cookie_name = cookie_name
      @trans_handler = trans_handler
      @trans_handler ||= TransHandler.instance
      @session_class = session_class
      @session_class ||= SBSM::Session
      @unknown_user = unknown_user.is_a?(Class) ? unknown_user.new : unknown_user
      @unknown_user ||= UnknownUser.new
      @validator = validator
    end

    def cap_max_sessions(now = Time.now)
      if @@sessions.size > self.class::CAP_MAX_THRESHOLD
        SBSM.info "too many sessions! Keeping only #{self.class::MAX_SESSIONS}"
        sess = nil
        @@sessions.values.sort[0...(-self.class::MAX_SESSIONS)].each { |sess|
          sess.__checkout
          @@sessions.delete(sess.key)
        }
        if sess
          age = sess.age(now)
          SBSM.info sprintf("deleted all sessions that had not been accessed for more than %im %is", age / 60, age % 60)
        end
      end
      seconds = (Time.now.to_i - now.to_i)
      SBSM.warn sprintf("cap_max_sessions to #{self.class::CAP_MAX_THRESHOLD}. took %d seconds", seconds)
    end

    def clean
      now = Time.now
      @@sessions.size
      @@sessions.delete_if do |key, s|
        if s.respond_to?(:expired?)
          if s.expired?(now)
            s.__checkout
            true
          else
            s.cap_max_states
            false
          end
        else
          true
        end
      rescue
        true
      end
      (Time.now.to_i - now.to_i)
      # SBSM.warn sprintf("Cleaned #{old_size - @@sessions.size} sessions. Took %d seconds", seconds)
    end

    def self.sessions
      @@sessions
    end

    def self.clear
      @@mutex.synchronize do
        @@sessions.each_value { |sess| sess.__checkout }
        @@sessions.clear
      end
    end

    def delete_session(key)
      if (sess = @@sessions.delete(key))
        sess.__checkout
      end
    end

    def reset
      @@mutex.synchronize {
        @@sessions.clear
      }
    end

    def run_cleaner
      # puts "running cleaner thread"
      Thread.new do
        Thread.current.abort_on_exception = true
        # Thread.current.priority = 1
        loop do
          sleep self.class::CLEANING_INTERVAL
          @@mutex.synchronize do
            clean
          end
        end
      end
    end

    def [](key)
      @@mutex.synchronize do
        unless (s = @@sessions[key]) && !s.expired?
          s = @@sessions[key] = @session_class.new(app: @app, cookie_name: @cookie_name, trans_handler: @trans_handler, validator: @validator, unknown_user: @unknown_user)
        end
        s.key = key
        s.reset
        s.touch
        s
      end
    end
  end
end
