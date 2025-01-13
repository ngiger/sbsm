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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA	02111-1307	USA
#
# ywesee - intellectual capital connected, Winterthurerstrasse 52, CH-8006 Zürich, Switzerland
# hwyss@ywesee.com
#
# LookandfeelWrapper -- sbsm -- hwyss@ywesee.com
#++

require "sbsm/lookandfeel"

module SBSM
  class LookandfeelWrapper < Lookandfeel
    def initialize(component)
      @component = component
      super(@component.session)
    end

    def respond_to_missing?(method_name, include_private = false)
      super
    end

    def method_missing(symbol, *args, &block)
      @component.send(symbol, *args, &block)
    end

    def attributes(key)
      self.class::HTML_ATTRIBUTES.fetch(key.to_sym) {
        @component.attributes(key)
      }
    end

    def disabled?(event)
      self.class::DISABLED.include?(event) \
        || @component.disabled?(event)
    end

    def enabled?(event, default = false)
      self.class::ENABLED.include?(event) \
        || @component.enabled?(event, default)
    end

    def languages
      unless @languages
        super
        if @languages.empty?
          @languages = @component.languages
        end
      end
      @languages
    end

    def lookup(key, *args, &block)
      _lookup(key, *args) || @component.lookup(key, *args, &block)
    end

    def navigation(filter = true)
      nav = @component.navigation(false)
      if filter
        nav.select { |item|
          key = item.is_a?(Symbol) ? item : item.direct_event
          enabled?(key)
        }
      else
        nav
      end
    end

    def resource(rname, rstr = nil)
      if self.class::RESOURCES.include?(rname)
        super
      else
        @component.resource(rname, rstr)
      end
    end

    def resource_global(rname, rstr = nil)
      if self.class::RESOURCES.include?(rname)
        super
      else
        @component.resource_global(rname, rstr)
      end
    end

    def zone_navigation(filter = true)
      nav = @component.zone_navigation(false)
      if filter
        nav.select { |item|
          key = item.is_a?(Symbol) ? item : item.direct_event
          enabled?(key)
        }
      else
        nav
      end
    end

    def zones(filter = true)
      nav = @component.zones(false)
      if filter
        nav.select { |item|
          key = item.is_a?(Symbol) ? item : item.direct_event
          enabled?(key)
        }
      else
        nav
      end
    end
  end
end
