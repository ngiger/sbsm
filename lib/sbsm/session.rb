#!/usr/bin/env ruby
# encoding: utf-8
#--
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
#	ywesee - intellectual capital connected, Winterthurerstrasse 52, CH-8006 Zürich, Switzerland
#	hwyss@ywesee.com
#
# SBSM::Session -- sbsm -- 27.09.2012 -- yasaka@ywesee.com
# SBSM::Session -- sbsm -- 17.01.2012 -- mhatakeyama@ywesee.com
# SBSM::Session -- sbsm -- 22.10.2002 -- hwyss@ywesee.com
#++

require 'cgi'
require 'sbsm/cgi'
require 'sbsm/state'
require 'sbsm/user'
require 'sbsm/lookandfeelfactory'
require 'delegate'

module SBSM
  class	Session < SimpleDelegator
		attr_reader :user, :active_thread, :key, :cookie_input, :cookie_name,
			:unsafe_input, :valid_input, :request_path, :cgi, :attended_states
    attr_accessor :validator, :trans_handler, :app, :options
		PERSISTENT_COOKIE_NAME = "sbsm-persistent-cookie"
		DEFAULT_FLAVOR = 'sbsm'
		DEFAULT_LANGUAGE = 'en'
		DEFAULT_STATE = State
		DEFAULT_ZONE = nil
    EXPIRES = 60 * 60
		LF_FACTORY = nil
		LOOKANDFEEL = Lookandfeel
		CAP_MAX_THRESHOLD = 8
		MAX_STATES = 4
		SERVER_NAME = nil
    UNKNOWN_USER = UnknownUser
    @@mutex = Mutex.new
    def Session.reset_stats
      @@stats = {}
    end
    reset_stats
    @@stats_ptrn = /./
    def Session.show_stats ptrn=@@stats_ptrn
      if ptrn.is_a?(String)
        ptrn = /#{ptrn}/i
      end
      puts sprintf("%8s %8s %8s %6s %10s Request-Path",
                   "Min", "Max", "Avg", "Num", "Total")
      grand_total = requests = all_max = all_min = 0
      @@stats.collect do |path, times|
        total = times.inject do |a, b| a + b end
        grand_total += total
        size = times.size
        requests += size
        max = times.max
        all_max = max > all_max ? max : all_max
        min = times.min
        all_min = min < all_min ? min : all_min
        [min, max, total / size, size, total, path]
      end.sort.each do |data|
        line = sprintf("%8.2f %8.2f %8.2f %6i %10.2f %s", *data)
        if ptrn.match(line)
          puts line
        end
      end
      puts sprintf("%8s %8s %8s %6s %10s Request-Path",
                   "Min", "Max", "Avg", "Num", "Total")
      puts sprintf("%8.2f %8.2f %8.2f %6i %10.2f",
                   all_min, all_max,
                   requests > 0 ? grand_total / requests : 0,
                   requests, grand_total)
      ''
    end

    # Session: It will be initialized indirectly whenever SessionStore cannot
    # find a session in it cache. The parameters are given via SBSM::App.new
    # which calls SessionStore.new
    #
    # === optional arguments
    #
    # * +validator+ -         A Ruby class overriding the SBSM::Validator class
    # * +trans_handler+ -     A Ruby class overriding the SBSM::TransHandler class
    # * +known_user+ -        Object wt SBSM::KnownUser class
    # * +cookie_name+ -       The cookie to save persistent user data
    #
    # === Examples
    # Look at steinwies.ch
    # * https://github.com/zdavatz/steinwies.ch (simple, mostly static files, one form, no persistence layer)
    #
    def initialize(app:,
                   trans_handler: nil,
                   validator: nil,
                   unknown_user: nil,
                   cookie_name: nil,
                   multi_threaded: false)
      SBSM.info "initialize th #{trans_handler} validator #{validator} app #{app.class}"
      @app = app
      @options = {}
      @unknown_user = unknown_user
      @unknown_user ||=  self.class::UNKNOWN_USER
      @unknown_user_class = @unknown_user.class
      @validator = validator
      @validator  ||= Validator.new
      fail "invalid validator #{@validator}" unless @validator.is_a?(SBSM::Validator)
      @trans_handler = trans_handler
      @trans_handler ||= TransHandler.instance
      fail "invalid trans_handler #{@trans_handler}" unless @trans_handler.is_a?(SBSM::TransHandler)
      @cookie_name =  cookie_name
      @cookie_name ||= self.class::PERSISTENT_COOKIE_NAME
      @@cookie_name = @cookie_name
      @attended_states = {}
      @persistent_user_input = {}
      @multi_threaded = multi_threaded
      @mutex = multi_threaded ? Mutex.new: @@mutex
      @active_thread = nil
      @variables = {}
      touch()
      reset_input()
      reset_cookie()
      logout
      @cgi = CGI.initialize_without_offline_prompt('html4')
      SBSM.debug "session initialized #{self} with @cgi #{@cgi} multi_threaded #{multi_threaded} app #{app.object_id}"
      super
    end
    def id
      self.object_id
    end
    def self.get_cookie_name
      @@cookie_name
    end
    def method_missing(symbol, *args, &block) # Replaces old dispatch to DRb
      @app.send(symbol, *args, &block)
    end if false
    def unknown_user
      @unknown_user_class.new
    end
    def age(now=Time.now)
      now - @mtime
    end
		def cap_max_states
			if(@attended_states.size > self::class::CAP_MAX_THRESHOLD)
				SBSM.info "too many states in session! Keeping only #{self::class::MAX_STATES}"
				sorted = @attended_states.values.sort
				sorted[0...(-self::class::MAX_STATES)].each { |state|
					state.__checkout
					@attended_states.delete(state.object_id)
				}
        @attended_states.size
			end
		end
		def __checkout
			@attended_states.each_value { |state| state.__checkout }
			@attended_states.clear
			flavor = @persistent_user_input[:flavor]
			lang = @persistent_user_input[:language]
			@persistent_user_input.clear
			@persistent_user_input.store(:flavor, flavor)
			@persistent_user_input.store(:language, lang)
			@valid_input.clear
			@unsafe_input.clear
			true
		end
    @@msie_ptrn = /MSIE/
    @@win_ptrn = /Win/i
		def client_activex?
      (ua = user_agent) && @@msie_ptrn.match(ua) && @@win_ptrn.match(ua)
		end
    @@nt5_ptrn = /Windows\s*NT\s*(\d+\.\d+)/i
		def client_nt5?
      (ua = user_agent) \
        && (match = @@nt5_ptrn.match(user_agent)) \
        && (match[1].to_f >= 5)
		end
		def cookie_set_or_get(key)
			if(value = @valid_input[key])
				set_cookie_input(key, value)
			else
				@cookie_input[key]
			end
		end
		def get_cookie_input(key)
			@cookie_input[key]
		end
		def default_language
			self::class::DEFAULT_LANGUAGE
		end
		def direct_event
      # used when
			@state.direct_event
		end
    def process_rack(rack_request:)
      start = Time.now
      @request_path ||= rack_request.path
      # binding.pry if rack_request.request_method.eql?('POST')
      rack_request.params.each { |key, val| @cgi.params.store(key, val) }
      @trans_handler.translate_uri(rack_request)
      html = @mutex.synchronize do
        begin
          @request_method =rack_request.request_method
          @request_path = rack_request.path
          validator.reset_errors() if validator && validator.respond_to?(:reset_errors)
          import_user_input(rack_request)
          import_cookies(rack_request)
          require 'pry'; binding.pry unless active_state.is_a?(SBSM::State)
          require 'pry'; binding.pry unless @state.is_a?(SBSM::State)
          # binding.pry if active_state.is_a?(DaVaz::State::Works::Movies)  || active_state.is_a?(DaVaz::State::Personal::Init)
          @state = active_state.trigger(event())
          require 'pry'; binding.pry unless @state.is_a?(SBSM::State)
          active_state
          SBSM.debug "active_state.trigger #{event()} state #{@state.object_id} #{@state.class} remember #{persistent_user_input(:remember).inspect}"
          #FIXME: is there a better way to distinguish returning states?
          #       ... we could simply refuse to init if event == :sort, but that
          #       would not solve the problem cleanly, I think.
          unless(@state.request_path)
            @state.request_path = @request_path
            @state.init
          end
          unless @state.volatile?
            SBSM.debug "Changing from #{@active_state.class} #{@active_state.object_id} to state #{@state.class} #{@state.object_id} remember #{persistent_user_input(:remember).inspect}"
            @active_state = @state
            @attended_states.store(@state.object_id, @state)
          else
            SBSM.debug "Stay in volatile state #{@state.class} #{@state.object_id} @active_state is #{@active_state.class}"
          end
          @zone = @active_state.zone
          @active_state.touch
          cap_max_states
        ensure
          @user_input_imported = false
        end
        to_html
      end
      (@@stats[@request_path] ||= []).push(Time.now - start)
      html
    rescue  => err
        SBSM.info "Error in process_rack #{err.backtrace[0..5].join("\n")}"
        raise err
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
			@valid_input[:event]
		end
    def event_bound_user_input(key)
      @event_user_input ||= {}
      evt = state.direct_event
      @event_user_input[evt] ||= {}
      if(val = user_input(key))
        @event_user_input[evt][key] = val
      else
        @event_user_input[evt][key]
      end
    end
		def expired?(now=Time.now)
      age(now) > EXPIRES
		end
		def force_login(user)
			@user = user
		end
		def import_cookies(request)
			reset_cookie()
      if(cuki_str = request.cookies[self::class::PERSISTENT_COOKIE_NAME])
        SBSM.debug "cuki_str #{self::class::PERSISTENT_COOKIE_NAME} #{cuki_str}"
        request.cookies.each do |key, val|
          key_sym = key.intern
          valid = @validator.validate(key_sym, val)
          @cookie_input.store(key_sym, valid) if valid
        end
        SBSM.debug "@cookie_input now #{@cookie_input}"
      end
		end
    # should matches stuff like  "hash[1]"
    @@hash_ptrn = /([^\[]+)((\[[^\]]+\])+)/
    @@index_ptrn = /[^\[\]]+/
    def import_user_input(rack_req)
			return if(@user_input_imported)
      hash = rack_req.env.merge rack_req.params
      hash.merge! rack_req.POST if rack_req.POST
      hash.delete('rack.request.form_hash')
      # SBSM.debug "hash has #{hash.size } items #{hash.keys}"
      hash.each do |key, value|
        next if /^rack\./.match(key)
				index = nil
				@unsafe_input.push([key.to_s.dup, value.to_s.dup])
				unless(key.nil? || key.empty?)
          if value.is_a?(Hash)
            key_sym = key.to_sym
            if @validator.validate(key_sym, value)
              @valid_input[key_sym] ||= {}
              value.each{ |k, v|
                          @valid_input[key_sym][k] = v
                        }
            end
            next
          end
          # Next for
					if match = @@hash_ptrn.match(key)
						key = match[1]
						index = match[2]
            # puts "key #{key} index #{index}  value #{value}"
					end
					key = key.intern
					if(key == :confirm_pass)
						pass = rack_req.params["pass"]
						SBSM.debug "pass:#{pass} - confirm:#{value}"
						@valid_input[key] = @valid_input[:set_pass] \
							= @validator.set_pass(pass, value)
					else
						valid = @validator.validate(key, value)
            # SBSM.debug "Checking #{key} -> #{value}  valid #{valid.inspect} index #{index.inspect}"
						if(index)
              target = (@valid_input[key] ||= {})
              indices = []
              index.scan(@@index_ptrn) { |idx|
                indices.push idx
              }
              last = indices.pop
              indices.each { |idx|
                target = (target[idx] ||= {})
              }
              target.store(last, valid)
						else
							@valid_input[key] = valid
						end
					end
				end
      end
			@user_input_imported = true
    end
		def infos
			@state.infos if @state.respond_to?(:infos)
		end
		def info?
			@state.info? if @state.respond_to?(:info?)
		end
		def is_crawler?
			@is_crawler ||= if @request.respond_to?(:is_crawler?)
                        @request.is_crawler?
                      end
		end
		def language
			cookie_set_or_get(:language) || default_language
		end
		def logged_in?
			!@user.is_a?(@unknown_user_class)
		end
		def login
      binding.pry
			if(user = (@app && @app.respond_to?(:login) && @app.login(self)))
          SBSM.debug "user is #{user}  #{request_path.inspect}"
				@user = user
      else
        SBSM.debug "login no user #{request_path.inspect}"
			end
		end
		def logout
			__checkout
			@user = unknown_user()
      @active_state = @state = self::class::DEFAULT_STATE.new(self, @user)
      SBSM.debug "logout #{request_path.inspect} setting @state #{@state.object_id} #{@state.class} remember #{persistent_user_input(:remember).inspect}"
      @state.init
			@attended_states.store(@state.object_id, @state)
		end
		def lookandfeel
			if(@lookandfeel.nil? \
				|| (@lookandfeel.flavor != flavor) \
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
			@flavor ||= begin
				user_input = persistent_user_input(:flavor)
				user_input ||= @valid_input[:default_flavor]
				lf_factory = self::class::LF_FACTORY
				if(lf_factory && lf_factory.include?(user_input))
					user_input
				else
					self::class::DEFAULT_FLAVOR
				end
			end
		end
		def http_headers
			@state.http_headers
		rescue NameError, StandardError => err
      SBSM.info "NameError, StandardError: #@request_path #{err}"
			{'Content-Type' => 'text/plain'}
		end
		def http_protocol
			@http_protocol ||=	if(@request.respond_to?(:server_port) \
														&& @request.server_port == 443)
														'https'
													else
														'http'
													end
		end
		def input_keys
			@valid_input.keys
		end
		def navigation
      ## return [] unless @user.respond_to?(:navigation) # eternal loop??
      require 'pry'; binding.pry unless @user.respond_to?(:navigation)
			@user.navigation
		end
		def passthru(*args)
			@request.passthru(*args)
		end
		def persistent_user_input(key)
			if(value = user_input(key))
				@persistent_user_input.store(key, value)
			else
				@persistent_user_input[key]
			end
		end
		def reset
      if @redirected
        SBSM.debug "reached Session::reset"
        @redirected = false
      else
        reset_input()
      end
		end
		def reset_cookie
			@cookie_input = {}
		end
    def reset_input
      @valid_input = {}
			@processing_errors = {}
			@http_protocol = nil
			@flavor = nil
			@unsafe_input = []
    end
		def remote_addr
			@remote_addr ||= if @request.respond_to?(:remote_addr)
				@request.remote_addr
			end
		end
		def remote_ip
			@remote_ip ||= if(@request.respond_to?(:remote_host))
				@request.remote_host
			end
		end
		def set_cookie_input(key, val)
      SBSM.debug "cookie_set_or_get #{key} #{val}"
			@cookie_input.store(key, val)
		end
		def server_name
			@server_name ||= if @request.respond_to?(:server_name)
				@request.server_name
			else
				self::class::SERVER_NAME
			end
		end
		def state(event=nil)
			@active_state
		end
    def touch
      @mtime = Time.now
      self
    end
		def to_html
			@state.to_html(cgi)
		end
    def user_agent
      @user_agent ||= (@request.user_agent if @request.respond_to?(:user_agent))
    end
    @@input_ptrn = /([^\[]+)\[([^\]]+)\]/
    def user_input(*keys)
			if(keys.size == 1)
				index = nil
				key = keys.first.to_s
				if match = @@input_ptrn.match(key)
					key = match[1]
					index = match[2]
				end
				key_sym = key.to_sym
				valid = @valid_input[key_sym]
				if(index && valid.respond_to?(:[]))
					valid[index]
				else
					valid
				end
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
    # https://ruby-doc.org/stdlib-2.3.1/libdoc/cgi/rdoc/CGI.html
    # should restore the values from a file, we return simply nothing
    def restore
      binding.pry
      {}
    end
    def update
      # nothing
    end
    def close
			#@unix_socket.stop_service
      # nothing
    end
    def delete
      @app.delete_session @key
    end
		def zone
			@valid_input[:zone] || @state.zone || self::class::DEFAULT_ZONE
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
			self.weighted_mtime <=> other.weighted_mtime
		end
		def [](key)
			@variables[key]
		end
		def []=(key, val)
			@variables[key] = val
		end
		private
		def active_state
			if(state_id = @valid_input[:state_id])
				@attended_states[state_id]
			end || @active_state
		end
		protected
		attr_reader :mtime
		def weighted_mtime
			@mtime + @user.session_weight
		end
  end
end
