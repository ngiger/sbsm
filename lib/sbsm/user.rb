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
# User -- sbsm -- 20.11.2002 -- hwyss@ywesee.com
#++

module SBSM
  class User
    HOME = nil
    NAVIGATION = []
    SESSION_WEIGHT = 1
    SESSION_WEIGHT_FACTOR = 60 * 15 # 15 Minutes
    def home
      self.class::HOME
    end

    def navigation
      self.class::NAVIGATION.dup
    end

    def pass
    end

    def session_weight
      self.class::SESSION_WEIGHT * SESSION_WEIGHT_FACTOR
    end
  end

  class UnknownUser < User
  end

  class KnownUser < User
    SESSION_WEIGHT = 2
  end
end
