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
# Lookandfeel -- sbsm -- hwyss@ywesee.com
#++
require "sbsm/time"
require "cgi"

module SBSM
  class Lookandfeel
    attr_reader :language, :flavor, :session
    DICTIONARIES = {}
    DISABLED = []
    ENABLED = []
    HTML_ATTRIBUTES = {}
    RESOURCES = {}
    RESOURCE_BASE = "resources"
    TXT_RESOURCES = "/resources"
    class << self
      def txt_file(filename)
        proc {
          path = File.expand_path(filename, self::TXT_RESOURCES)
          File.read(path).strip.gsub(/(\r\n)|(\n)|(\r)/, "<br>")
        }
      end
    end
    def initialize(session)
      @session = session
      @flavor = @session.flavor
      @language = @session.language
      set_dictionary(@language)
    end

    def attributes(key)
      self.class::HTML_ATTRIBUTES.fetch(key.to_sym, {}).dup
    rescue
      {}
    end

    def base_url
      maybe_port = @session.server_port ? (":" + @session.server_port) : ""
      [@session.http_protocol + ":/", @session.server_name + maybe_port, @language, @flavor].compact.join("/")
    end

    def direct_event
      @session.direct_event
    end

    def disabled?(event)
      self.class::DISABLED.include?(event)
    end

    def enabled?(event, default = true)
      default || self.class::ENABLED.include?(event)
    end

    def event_url(event = direct_event, args = {}, anchor = nil)
      _event_url(event, args, nil) { |args|
        unless @session.is_crawler? || args.include?("state_id")
          args.unshift(:state_id, @session.state.object_id)
        end
      }
    end

    def _event_url(event = direct_event, args = {}, anchor = nil, &block)
      args = args.collect { |*pair| pair }.flatten
      args = args.collect { |value| CGI.escape(value.to_s) }
      if block_given?
        yield(args)
      end
      url = [base_url, event, args].compact.join("/")
      if anchor
        url << "#" << anchor.to_s
      end
      url
    end

    def languages
      @languages ||= self.class::DICTIONARIES.keys.sort
    end

    def language_url(language)
      base_url
    end

    def lookup(key, *args, &block)
      _lookup(key, *args) || block&.call
    end

    def _lookup(key, *args)
      key = key.intern if key.is_a? String
      if args.size > 0
        result = ""
        args.each_with_index { |text, index|
          result += lookup(key.to_s + index.to_s) || " "
          result += text.to_s
        }
        tail = lookup(key.to_s + args.size.to_s)
        result << tail if tail
      else
        result = @dictionary[key] if @dictionary
        if result.is_a? Proc
          result.call
        elsif result.nil?
          def_lan = @session.default_language
          if (dict = self.class::DICTIONARIES[def_lan])
            dict[key]
          end
        else
          result
        end
      end
    end

    def format_date(date)
      date.strftime(lookup(:date_format))
    end

    def format_price(price, currency = nil)
      if price.to_i > 0
        [currency, sprintf("%.2f", price.to_f / 100.0)].compact.join(" ")
      end
    end

    def format_time(time)
      time.strftime(lookup(:time_format))
    end

    def navigation(filter = false)
      @session.navigation
    end

    def resource(rname, rstr = nil)
      collect_resource([self.class::RESOURCE_BASE, @session.flavor],
        rname, rstr)
    end

    def resource_external(rname)
      self.class::RESOURCES[rname]
    end

    def resource_global(rname, rstr = nil)
      collect_resource(self.class::RESOURCE_BASE, rname, rstr)
    end

    def resource_localized(rname, rstr = nil, lang = @language)
      result = resource([rname, lang].join("_").intern, rstr)
      if result.nil? && (lang != @session.default_language)
        result = resource_localized(rname, rstr, @session.default_language)
      end
      result
    end

    def zone_navigation(filter = false)
      @session.zone_navigation
    end

    def zones(filter = false)
      @session.zones
    end

    private

    def collect_resource(base, rname, rstr = nil)
      varpart = self.class::RESOURCES[rname]
      if varpart.is_a?(Array)
        varpart.collect { |part|
          _collect_resource(base, part, rstr)
        }
      elsif !varpart.nil?
        _collect_resource(base, varpart, rstr)
      end
    end

    def _collect_resource(base, part, rstr)
      maybe_port = @session.server_port ? (":" + @session.server_port) : ""
      [@session.http_protocol + ":/", @session.server_name + maybe_port, base, part, rstr].flatten.compact.join("/")
    end

    def set_dictionary(language)
      @dictionary = self.class::DICTIONARIES[language] || {}
    end
  end
end
