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
# Session -- sbsm -- 22.10.2002 -- hwyss@ywesee.com 

require 'drb/drb'
require 'sbsm/cgi'
require 'sbsm/state'
require 'sbsm/lookandfeelfactory'
require 'delegate'

module SBSM
  class	Session < SimpleDelegator
		attr_reader :user, :active_thread, :app, :key
		include DRbUndumped 
		DEFAULT_FLAVOR = nil
		DEFAULT_LANGUAGE = nil
		DEFAULT_STATE = State
		DEFAULT_ZONE = nil
		DRB_LOAD_LIMIT = 255 * 1024
    EXPIRES = 60 * 60
		LF_FACTORY = nil
		LOOKANDFEEL = Lookandfeel
		CAP_MAX_THRESHOLD = 20
		MAX_STATES = 10
		SERVER_NAME = nil
    def initialize(key, app, validator=nil)
			touch()
      reset_input()
			ARGV.push('') # satisfy cgi-offline prompt 
      @app = app
			@cgi = CGI.new('html4')
      @hash = {
        :proxy   =>  self,
      }
			@hash.extend(DRbUndumped) # added for Ruby1.8 compliance
			@html_packets = nil
      @key = key
			@validator = validator
			#@cached_states = {}
			@attended_states = {}
			@persistent_user_input = {}
			logout()
			@active_state = @state = self::class::DEFAULT_STATE.new(self, @user)
			@unknown_user_class = @user.class
			super(app)
    end
		def cap_max_states
			if(@attended_states.size > self::class::CAP_MAX_THRESHOLD)
				#puts "too many states in session! Keeping only #{self::class::MAX_STATES}"
				sorted = @attended_states.values.sort
				sorted[0...(-self::class::MAX_STATES)].each { |state|
					state.checkout
					@attended_states.delete(state.id)
					#@cached_states.delete_if { |key, cached|
					#	cached.id == state.id
					#}
				}
			end
		end
		def default_language
			self::class::DEFAULT_LANGUAGE
		end
		def direct_event
			@state.direct_event
		end
		def error(key)
			@state.error(key) if @state.respond_to?(:error)
		end
		def errors
			@state.errors.values if @state.respond_to?(:errors)
		end
		def error?
			@state.error? if @state.respond_to?(:error?)
		end
		def event
			user_input(:event)
		end
		def expired?
      Time.now - @mtime > EXPIRES
		end
    def import_user_input(request)
			# attempting to read the cgi-params more than once results in a
			# DRbConnectionRefused Exception. Therefore, do it only once...
			return if(@user_input_imported) 
      reset_input()
      request.params.each { |key, value| 
				#puts "importing #{key} -> #{value}"
				index = nil
				unless key.nil?
					if match = /([^\[]+)\[([^\]]+)\]/.match(key)
						key = match[1]
						index = match[2]
						#puts key, index
					end
					key = key.intern 
					if(key == :confirm_pass)
						pass = request.params["pass"]
						#puts "pass:#{pass} - confirm:#{value}"
						@valid_input[key] = @valid_input[:set_pass] \
							= @validator.set_pass(pass, value)
					else
						valid = @validator.validate(key, value)
						if(index)
							(@valid_input[key] ||= {}).store(index, valid)
						else
							@valid_input[key] = valid
						end
					end
				end
				#puts "imported #{key} -> #{value} => #{@valid_input[key].inspect}"
      }
			@user_input_imported = true
			#puts @valid_input.inspect
    end
		def infos
			@state.infos if @state.respond_to?(:infos)
		end
		def info?
			@state.info? if @state.respond_to?(:info?)
		end
		def language
			persistent_user_input(:language) \
				|| self::class::DEFAULT_LANGUAGE
		end
		def logged_in?
			!@user.is_a?(@unknown_user_class)
		end
		def login
			if(user = @app.login(self))
				@user = user
			end
		end
		def logout
			#@cached_states.clear
			@attended_states.clear
			@persistent_user_input.clear
			@user = @app.unknown_user()
		end
		def lookandfeel
			if(@lookandfeel.nil? \
				|| (@lookandfeel.flavor != persistent_user_input(:flavor)) \
				|| (@lookandfeel.language != persistent_user_input(:language)))
				@lookandfeel = if self::class::LF_FACTORY
					self::class::LF_FACTORY.create(self)
				else
					self::class::LOOKANDFEEL.new(self)
				end
			end
			@lookandfeel
		end
		def flavor
			user_input = persistent_user_input(:flavor)
			lf_factory = self::class::LF_FACTORY
			if(lf_factory && lf_factory.include?(user_input))
				user_input
			else	
				self::class::DEFAULT_FLAVOR
			end
		end
		def http_headers
			@state.http_headers
		end
		def http_protocol
			@http_protocol ||= if(@request.respond_to?(:server_protocol) && 
				/https/i.match(@request.server_protocol))
				'https'
			else
				'http'
			end
		end
		def navigation
			@user.navigation
		end
		def next_html_packet
			html_safe_wrap {
				@html_packets = to_html unless @html_packets
				@html_packets.slice!(0, self::class::DRB_LOAD_LIMIT) unless @html_packets.empty?
			}
		end
		def passthru(path)
			@request.passthru(path)
		end
		def persistent_user_input(key)
			if (value = user_input(key))
				@persistent_user_input.store(key, value)
			else
				@persistent_user_input[key]
			end
		end
		def process(request)
			begin
				@request = request
				@validator.reset_errors() if @validator
				import_user_input(request)
				@state = active_state.trigger(event()) 
				@state.reset_view
				@state.touch
				unless @state.volatile?
					@active_state = @state
				end
				@attended_states.store(@state.id, @state)
				@app.async { cap_max_states }
			rescue StandardError => e
				puts "error in SBSM::Session#process"
				puts e.class
				puts e.message
				puts e.backtrace
				$stdout.flush
			ensure
				@user_input_imported = false
			end
			''
		end
		def reset
			if(@active_thread && 
				!@active_thread.stop? && 
				@active_thread!=Thread.current)
				p "killing #{@active_thread}"
				begin
					if(old_request = @active_thread[:request])
						p "...and aborting old request"
						old_request.abort
					end
					@active_thread.exit 
				rescue StandardError
				end
			end
			@active_thread = Thread.current
			reset_input()
			@html_packets = nil
		end
    def reset_input
      @valid_input = {}
			@processing_errors = {}
    end
		def remote_addr
			@remote_addr ||= if @request.respond_to?(:remote_addr)
				@request.remote_addr
			end
		end
		def server_name
			@server_name ||= if @request.respond_to?(:server_name)
				@request.server_name 
			else
				self::class::SERVER_NAME
			end
		end
		def state(event=nil)
			#if(event.nil?)
				@active_state
			#else
			#	@cached_states.fetch(event) {
			#		@active_state
			#	}
			#end
		end
    def touch
      @mtime = Time.now
      self
    end
		def to_html
			html_safe_wrap {
				@state.to_html(@cgi)
			}
		end
    def user_input(*keys)
			if(keys.size == 1)
				key = keys.first
				key_sym = (key.is_a? Symbol) ? key : key.to_s.intern
				@valid_input[key_sym]
			else
				keys.inject({}) { |inj, key|
					inj.store(key, user_input(key))
					inj
				}
			end
    end
		def valid_values(key)
			vals = @validator.valid_values(key) unless @validator.nil?
			vals || []
		end
		def warnings
			@state.warnings if @state.respond_to?(:warnings)
		end
		def warning?
			@state.warning? if @state.respond_to?(:warning?)
		end
    # CGI::SessionHandler compatibility
    def restore
			#puts "restore was called"
      @hash
    end
    def update
      # nothing
    end
    def close
      # nothing
    end
    def delete
      @app.delete_session @key
    end
		def zone
			persistent_user_input(:zone) || self::class::DEFAULT_ZONE
		end
		def zones 
			@active_state.zones
		end
		def zone_navigation
			@state.zone_navigation
		end
		def ==(other)
			super
		end
		def <=>(other)
			@mtime <=> other.mtime	
		end
		private
		def active_state
			if(state_id = user_input(:state_id))
				@attended_states[state_id]
			end || @active_state
		end
		def html_safe_wrap(&block)
			begin
				block.call
			rescue StandardError => e
				msg = [
					e.class,
					e.message,
					e.backtrace.join("<br>"),
				].join("</p><p>")
				"<p>" << msg << "</p>"
			end
		end
		protected
		attr_reader :mtime
  end
end