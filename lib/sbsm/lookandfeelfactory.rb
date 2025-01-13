#!/usr/bin/env ruby

#--
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
# LookandfeelFactory -- sbsm -- hwyss@ywesee.com
#++
require "sbsm/lookandfeel"

module SBSM
  class LookandfeelFactory
    WRAPPERS = {}
    BASE = Lookandfeel
    class << self
      def create(session)
        lnf = self::BASE.new(session)
        if (wrappers = self::WRAPPERS[session.flavor])
          lnf = wrappers.inject(lnf) { |lnf, klass|
            klass.new(lnf)
          }
        end
        lnf
      rescue => e
        puts e.class
        puts e.message
        puts e.backtrace
      end

      def include?(str)
        self::WRAPPERS.include?(str)
      end
    end
  end
end
