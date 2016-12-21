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
# Validator -- sbsm -- 15.11.2002 -- hwyss@ywesee.com 
#++

require 'digest/md5'
require 'mail'
require 'date'
require 'drb/drb'
require 'uri'
require 'stringio'
require 'hpricot'
require 'sbsm/logger'

module SBSM
	class InvalidDataError < RuntimeError
		attr_reader :key, :value
		alias :data :value 
		def initialize(msg, key, value)
			super("#{msg.to_s} #{key.to_s[0..79]} #{value.to_s[0..79]}")
			@key = key
			@value = value
		end
	end
	class Validator
		BOOLEAN = []
		DATES = []
		ENUMS = {}
		EVENTS = []
		FILES = []
    HTML = []
		NUMERIC = []
		PATTERNS = {}
		STRINGS = []
		URIS = []
    ALLOWED_TAGS = %{a b br div font h1 h2 h3 i img li ol p pre span strong u ul}
		def initialize
			reset_errors()
			@boolean = self::class::BOOLEAN.dup
			@dates = self::class::DATES.dup
			@enums = self::class::ENUMS.dup
			@events = self::class::EVENTS.dup
			@files = self::class::FILES.dup
			@html = self::class::HTML.dup
			@numeric = self::class::NUMERIC.dup
			@patterns = self::class::PATTERNS.dup
			@strings = self::class::STRINGS.dup
			@uris = self::class::URIS.dup
		end	
		def error?
			!@errors.empty?
		end
		def reset_errors
			@errors = {}
		end	
		def set_pass(value1, value2)
			valid1 = pass(value1.to_s)
			valid2 = pass(value2.to_s)
			if(value1.to_s.empty?)
				SBSM::InvalidDataError.new(:e_empty_pass, :pass, '')
			elsif(valid1 != valid2)
				SBSM::InvalidDataError.new(:e_non_matching_pass, :pass, '')
			else
				valid1
			end
		end
		def valid_values(key)
			key = key.intern if key.is_a? String
			@enums.fetch(key)	{
				if(@boolean.include?(key))
					['false', 'true']
				end
			}
		end
		def validate(key, value)
			value = value.pop if value.is_a? Array
			return nil if value.nil?
      if value.is_a?(StringIO)
				if(@files.include?(key))
					return validate_file(key, value)
				else
					begin
						value = value.read
					rescue StandardError => e
						p e
					end
				end
			elsif(value.is_a? DRb::DRbObject)
				value = value[0]
				if(@files.include?(key))
					return validate_file(key, value)
				else
					begin
						value = value.read
					rescue StandardError => e
						#p e
					end
				end
			end
      perform_validation(key, value)
    end
    def perform_validation(key, value)
			value = value.to_s.strip
			begin
				if(key==:event)
					symbol = value.to_sym
					symbol if @events.include?(symbol)
				elsif(@boolean.include?(key))
					validate_boolean(key, value)
				elsif(@dates.include?(key))
					validate_date(key, value)
				elsif(@enums.has_key?(key))
					value if @enums[key].include?(value)
				elsif(@html.include?(key))
					validate_html(value)
				elsif(@patterns.include?(key))
					validate_pattern(key, value)
				elsif(@numeric.include?(key))
					validate_numeric(key, value)
				elsif(@uris.include?(key))
					validate_uri(key, value)
				elsif(@strings.include?(key))
					validate_string(value)
        elsif(@files.include?(key))
          StringIO.new(value)
				elsif(!Object.methods.include?(key) and self.respond_to?(key, true))
					self.send(key, value)
				end
			rescue InvalidDataError => e
        SBSM.debug("#{e.key} #{e}")
				@errors.store(e.key, e)
			end
		end
		private
		def email(value)
			return if(value.empty?)
			parsed = Mail::Address.new(value)
			if(parsed.nil?)
			  raise InvalidDataError.new(:e_invalid_email_address, :email, value)
				elsif (parsed.domain)
				parsed.to_s
			else
				raise InvalidDataError.new(:e_invalid_email_address, :email, value)
			end
		rescue => e
			if e.class == SBSM::InvalidDataError
				raise e
			else
				raise InvalidDataError.new(:e_invalid_email_address, :email, value)
			end
		end
		def filename(value)
			if(value == File.basename(value))
				value
			end
		end
		def flavor(value)
			validate_string(value)
		end
		alias :default_flavor :flavor
		def language(value)
			validate_string(value)
		end
		def pass(value)
      unless(value.empty?)
			  Digest::MD5::hexdigest(value)
      end
		end
		alias :confirm_pass :pass
    @@state_id_ptrn = /-?\d+/
		def state_id(value)
			if(match = @@state_id_ptrn.match(value))
				match[0].to_i
			else
				nil
			end
		end
		def validate_boolean(key, value)
			case value.to_s.downcase
			when 'true', '1', 'y', 'j'
				true
			when 'false', '0', 'n'
				false
			else 
				raise InvalidDataError.new(:e_invalid_boolean, key, value)
			end
		end
		def validate_date(key, value)
			return nil if (value.empty?)
			begin
				Date.parse(value.tr('.', '-'))
			rescue ArgumentError
				raise InvalidDataError.new(:e_invalid_date, key, value)
			end
		end
		def validate_file(key, value)
			return nil if value.original_filename.empty?
			value
		end
    def validate_html(value)
      _validate_html(value)
    end
    @@xml_ptrn = /<\?xml[^>]+>/
    def _validate_html(value, valid=self.class.const_get(:ALLOWED_TAGS))
			doc = Hpricot(value.gsub(@@xml_ptrn, ''), :fixup_tags => true)
      (doc/"*").each { |element|
        unless(element.is_a?(Hpricot::Text) \
               || (element.respond_to?(:name) \
                   && valid.include?(element.name.downcase)))
          element.swap _validate_html(element.inner_html.to_s)
        end
      }
      valid = doc.to_html
      valid.force_encoding 'UTF-8' if valid.respond_to?(:force_encoding)
      valid
    end
    @@numeric_ptrn = /\d+(\.\d{1,2})?/
		def validate_numeric(key, value)
			return if(value.empty?)
			if(match = @@numeric_ptrn.match(value))
				match[0]
			else
				raise InvalidDataError.new("e_invalid_#{key}", key, value)
			end
		end
		def validate_pattern(key, value)
			pattern = @patterns[key] 
			if(match = pattern.match(value))
				match[0]
			end
		end
		def validate_string(value)
      _validate_html(value, [])
		end
		def validate_uri(key, value)
			uri = URI.parse(value)
			if(uri.scheme.nil?)
				uri = URI.parse('http://' << value)
			end
			uri
		rescue 
			raise InvalidDataError.new(:e_invalid_uri, key, value)
		end
	end
end
