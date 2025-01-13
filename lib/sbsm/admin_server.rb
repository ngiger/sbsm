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
#++
# AdminServer -- sbsm -- niger@ywesee.com
#  2017: Moved the old _admin interface into a separate class for BBMB and Virbac

require "delegate"
require "sbsm/session"
require "sbsm/user"
require "digest/md5"
require "sbsm/logger"
require "sbsm/session_store"

module SBSM
  # AdminClass must be tied to an Rack app
  class AdminServer
    def initialize(app:, multi_threaded: false)
      @session = SBSM::SessionStore.new(app: app, multi_threaded: multi_threaded)
      @admin_threads = ThreadGroup.new
    end

    def _admin(src, result, priority = 0)
      t = Thread.new {
        Thread.current.abort_on_exception = false
        result << begin
          response = begin
            instance_eval(src)
          rescue NameError => e
            e
          end
          str = response.to_s
          if str.length > 200
            response.class
          else
            str
          end
        rescue => e
          e.message
        end.to_s
      }
      t[:source] = src
      t.priority = priority
      @admin_threads.add(t)
      t
    end
  end
end
