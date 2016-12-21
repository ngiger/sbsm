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
# DrbServer -- sbsm -- hwyss@ywesee.com
#++

require 'delegate'
require 'sbsm/drb'
require 'sbsm/session'
require 'sbsm/user'
require 'thread'
require 'digest/md5'
require 'sbsm/logger'
require 'sbsm/validator'

module SBSM
	class DRbServer < SimpleDelegator
		include DRbUndumped
		CLEANING_INTERVAL = 30
		CAP_MAX_THRESHOLD = 120
		ENABLE_ADMIN = false
		MAX_SESSIONS = 100
		RUN_CLEANER = true
		SESSION = Session
		UNKNOWN_USER = UnknownUser
		VALIDATOR = nil
		attr_reader :cleaner, :updater
		def initialize(persistence_layer=nil)
			@sessions = {}
			@mutex = Mutex.new
			@cleaner = run_cleaner if(self.class.const_get(:RUN_CLEANER))
			@admin_threads = ThreadGroup.new
			@async = ThreadGroup.new
			@system = persistence_layer
			super(persistence_layer)
		end
		def _admin(src, result, priority=0)
			raise "admin interface disabled" unless(self::class::ENABLE_ADMIN)
			t = Thread.new {
				Thread.current.abort_on_exception = false
				result << begin
					response = begin
						instance_eval(src)
					rescue NameError => e
						e
					end
					str = response.to_s
					if(str.length > 200)
						response.class
					else
						str
					end
				rescue StandardError => e
					e.message
				end.to_s
			}
			t[:source] = src
			t.priority = priority
			@admin_threads.add(t)
			t
		end
		def async(&block)
			@async.add(Thread.new(&block))
		end
		def cap_max_sessions(now = Time.now)
			if(@sessions.size > self::class::CAP_MAX_THRESHOLD)
				SBSM.info "too many sessions! Keeping only #{self::class::MAX_SESSIONS}"
        sess = nil
				sorted = @sessions.values.sort
				sorted[0...(-self::class::MAX_SESSIONS)].each { |sess|
					sess.__checkout
					@sessions.delete(sess.key)
				}
        if(sess)
          age = sess.age(now)
          SBSM.info sprintf("deleted all sessions that had not been accessed for more than %im %is", age / 60, age % 60)
        end
			end
		end
		def clean
      now = Time.now
			@sessions.delete_if { |key, s| 
        begin
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
			}
			#cap_max_sessions(now)
		end
		def clear
			@sessions.each_value { |sess| sess.__checkout }
			@sessions.clear
		end
		def delete_session(key)
			if(sess = @sessions.delete(key))
				sess.__checkout
			end
		end
		def reset
			@mutex.synchronize {
				@sessions.clear
			}
		end
		def run_cleaner
			# puts "running cleaner thread"
			Thread.new {
				Thread.current.abort_on_exception = true
				#Thread.current.priority = 1
				loop {
					sleep self::class::CLEANING_INTERVAL
					@mutex.synchronize {
						clean()
					}
				}
			}
		end
		def unknown_user
			self::class::UNKNOWN_USER.new
		end
    def [](key)
      @mutex.synchronize {
        unless((s = @sessions[key]) && !s.expired?)
          args = [key, self]
          if(klass = self::class::VALIDATOR)
            args.push(klass.new)
          end
          s = @sessions[key] = self::class::SESSION.new(*args.compact)
        end
        s.reset()
        s.touch()
        s
      }
    end
	end
end
