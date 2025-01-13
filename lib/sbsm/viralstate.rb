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
# ViralState -- sbsm -- 16.04.2004 -- hwyss@ywesee.com
#++

module SBSM
  module ViralState
    VIRAL = true
    def infect(newstate)
      @viral_modules.uniq.each { |mod|
        newstate.extend(mod) unless newstate.is_a?(mod)
      }
      newstate
    end

    def trigger(event)
      newstate = super
      if event == :logout
        @session.logout
      else
        infect(newstate)
      end
      newstate
    rescue RangeError
      @session.logout
      home
    end
  end
end
