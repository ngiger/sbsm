#!/usr/bin/env ruby
#
# State Based Session Management	
#	Copyright (C) 2004 Hannes Wyss
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
#	ywesee - intellectual capital connected, Winterthurerstrasse 52, CH-8006 Z�rich, Switzerland
#	hwyss@ywesee.com
#
# LookandfeelWrapper -- sbsm -- hwyss@ywesee.com

require "sbsm/lookandfeel"

module SBSM
  class LookandfeelWrapper < Lookandfeel
		ENABLED = []
    def initialize(component)
      super component.session
      @component = component
    end 
    def method_missing(symbol, *args, &block)
      @component.send(symbol, *args, &block)
    end
		def attributes(key)
			self::class::HTML_ATTRIBUTES.fetch(key) {
				@component.attributes(key)
			}
		end
		def enabled?(event, default=false)
			self::class::ENABLED.include?(event) \
				|| @component.enabled?(event, default)
		end
    def lookup(key, *args)
      super or @component.lookup(key, *args)
    end
		def navigation(filter=true)
			nav = @component.navigation(false)
			if(filter)
				nav.select { |item| 
					key = (item.is_a? Symbol) ? item : item.direct_event
					enabled?(key)
				}
			else
				nav
			end
		end
		def resource(rname, rstr=nil)
			if(self::class::RESOURCES.include?(rname))
				super
			else
				@component.resource(rname, rstr)
			end
		end
		def resource_global(rname, rstr=nil)
			if(self::class::RESOURCES.include?(rname))
				super
			else
				@component.resource_global(rname, rstr)
			end
		end
  end
end