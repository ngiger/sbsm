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
# State -- sbsm -- 22.10.2002 -- hwyss@ywesee.com 

module SBSM
	class ProcessingError < RuntimeError
		attr_reader :key, :value
		def initialize(message,	key, value)
			super(message)
			@key = key
			@value = value
		end
	end
	class Warning
		attr_reader :key, :value, :message
		def initialize(message, key, value)
			@message = message
			@key = key
			@value = value
		end
	end
	class HtmlStub
		attr_accessor :to_html
	end
	class State
		attr_reader :errors, :infos, :events
		attr_reader :previous, :warnings
		attr_accessor :next
		DIRECT_EVENT = nil
		ZONE = nil
		ZONES = []
		ZONE_EVENT = nil
		EVENT_MAP = {}
		GLOBAL_MAP = {}
		VIEW = nil
		VOLATILE = false
		def State::direct_event
			self::DIRECT_EVENT
		end
		def State::zone
			self::ZONE
		end
		def State::zones
			self::ZONES
		end
		def initialize(session, model)
			@session = session
			@model = model
			@events = self::class::GLOBAL_MAP.dup.update(self::class::EVENT_MAP.dup)
			@view = nil
			@default_view = self::class::VIEW
			@errors = {}
			@infos = []
			@warnings = []
			touch()
			init()
		end
		def add_warning(message, key, value)
			if(key.is_a? String)
				key = key.intern
			end
			warning = Warning.new(message, key, value)
			@warnings.push(warning)
		end
		def checkout
			if(@next.respond_to?(:unset_previous))
				@next.unset_previous
			end
			if(@next.respond_to?(:checkout))
				@next.checkout
			end
			@next = nil
		end
		def create_error(msg, key, val)
			ProcessingError.new(msg.to_s, key, val)
		end
		def default 
			self
		end
		def direct_event
			self::class::DIRECT_EVENT
		end
		def error?
			!@errors.empty?
		end
		def error(key)
			@errors[key]
		end
		def error_check_and_store(key, value, mandatory=[])
			if(value.is_a? RuntimeError)
				@errors.store(key, value)
			elsif(mandatory.include?(key) && mandatory_violation(value))
				error = create_error('e_missing_' << key.to_s, key, value)
				@errors.store(key, error)
			end
		end
		def extend(mod)
			if(mod.constants.include?('VIRAL'))
				@viral_module = mod 
			end
			if(mod.constants.include?('EVENT_MAP'))
				@events.update(mod::EVENT_MAP)
			end
			super
		end
		def http_headers
			view.http_headers
		end
		def info?
			!@infos.empty?
		end
		def info(key)
			@infos[key]
		end
		def mandatory_violation(value)
			value.nil? || (value.respond_to?(:empty?) && value.empty?)
		end
		def previous=(state)
			if(@previous.nil? && state.respond_to?(:next=))
				state.next = self
				@previous = state
			end
		end
		def reset_view
			@view = nil
		end
		def touch
			@mtime = Time.now
		end
		def to_html(context)
			begin
				html_output = view.to_html(context)
				#		view.explode!
				html_output
			rescue StandardError => e
				puts "error in SBSM::State#to_html"
				puts e.class
				puts e.message
				puts e.backtrace
				if(@previous) 
					begin
						@previous.to_html(context)
					rescue StandardError => f
						"Fatal: @previous.to_html raised #{f}"
					end
				else
					"Fatal: no previous State!"
				end
			end
		end
		def trigger(event)
			@errors = {}
			@infos = []
			@warnings = []
			state = if(event && !event.to_s.empty? && self.respond_to?(event))
				self.send(event) 
			elsif(klass = @events[event])
				klass.new(@session, @model)
			end
			state ||= self.default
			if(state.respond_to?(:previous=))
				state.previous = self 
			end
			state 
		end
		def unset_previous
			@previous = nil
		end
		def warning(key)
			@warnings.select { |warning| warning.key == key }.first
		end
		def warning?
			!@warnings.empty?		
		end
=begin
		def user_input(keys)
			keys.inject({}) { |inj, key|
				value = @session.user_input(key)
				if(value.is_a? RuntimeError)
					@errors.store(key, value)
				else
					inj.store(key, value)
				end
				inj
			}
		end
=end
		def user_input(keys=[], mandatory=[])
			keys = [keys] unless keys.is_a?(Array)
			mandatory = [mandatory] unless mandatory.is_a?(Array)
			if(hash = @session.user_input(*keys))
				hash.each { |key, value| 
					if(error_check_and_store(key, value, mandatory))
						hash.delete(key)
					end
				}
				hash
			else
				{}
			end
		end
		def view
			#puts "view start"
			begin
				if(@view.nil?)
					#puts "view was not initialized. doing it now..."
					klass = @default_view
					if(klass.is_a?(Hash))
						klass = klass.fetch(@session.user.class) {
							klass[:default]
						}
					end
					#puts "view will be a #{klass}"
					model = if(@filter.is_a? Proc)
					#puts "filtering the model"
						@filter.call(@model)
					else
						@model
					end
					#puts "creating the actual view of klass: #{klass}"
					#puts model.class
					#puts @session.class
					@view = klass.new(model, @session)	
					#puts "the view is #{@view}"
				end
				@view
			rescue StandardError => e
				puts "error in SBSM::State#view"
				puts e.class
				puts e.message
				puts e.backtrace
				if(@previous)
					begin
						view = @previous.view 
						@previous.reset_view	
						view
					rescue
						stub = HtmlStub.new
						stub.to_html = 'fatal: could not get view'
						stub
					end
				else
					stub = HtmlStub.new
					stub.to_html = 'fatal: could not get view'
					stub
				end
			end
		end
		def volatile?
			self::class::VOLATILE
		end
		def zone 
			self::class::ZONE
		end
		def zones 
			self::class::ZONES
		end
		def zone_navigation
			[]
		end
		def <=>(other)
			@mtime <=> other.mtime
		end
		private
		def init
		end
		protected
		attr_reader :mtime
	end
end