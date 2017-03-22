#!/usr/bin/env ruby
# encoding: utf-8
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
# ngiger@ywesee.com
#
# App -- sbsm -- ngiger@ywesee.com
#++
require 'cgi'
require 'cgi/session'
require 'sbsm/cgi'
require 'sbsm/trans_handler'
require 'sbsm/validator'
require 'sbsm/user'
require 'mimemagic'

module SBSM
  ###
  # App as a member of session
  class App
    def initialize()
      SBSM.info "initialize"
    end
  end

  class RackInterface
    attr_accessor :session, :options # thread variable!
    attr_reader   :session_store
    attr_reader   :cleaner, :updater, :persistence_layer, :cookie_name, :expires
    REPEATABLE_SESSION_IDS = true # This should be set to true only to ease debugging a problem.
    $SBSM_app_session_id = 0 if REPEATABLE_SESSION_IDS
    UNKNOWN_USER = UnknownUser
    VALIDATOR = nil
    RUN_CLEANER = true

    # Base class for a SBSM based WebRick HTTP server
    # * offer a call(env) method form handling the WebRick requests
    # This is all what is needed to be compatible with WebRick
    #
    # === optional arguments
    #
    # * +app+ -               A Ruby class used by the session
    # * +validator+ -         A Ruby class overriding the SBSM::Validator class
    # * +trans_handler+ -     A Ruby class overriding the SBSM::TransHandler class
    # * +session_class+ -     A Ruby class overriding the SBSM::Session class
    # * +unknown_user+ -      A Ruby class overriding the SBSM::UnknownUser class
    # * +persistence_layer+ - Persistence Layer to use
    # * +cookie_name+ -       The cookie to save persistent user data
    # * +multi_threaded+ -    Allow multi_threaded SBSM (default is false)
    #
    # === Examples
    # Look at steinwies.ch
    # * https://github.com/zdavatz/steinwies.ch (simple, mostly static files, one form, no persistence layer)
    #
    def initialize(app:,
                   validator: nil,
                   trans_handler:  nil,
                   session_class: nil,
                   persistence_layer: nil,
                   unknown_user: nil,
                   cookie_name: nil,
                   multi_threaded: nil
                 )
      @@last_session = nil
      @app = app
      SBSM.info "initialize validator #{validator} th #{trans_handler} cookie #{cookie_name} session #{session_class} app #{app} multi_threaded #{multi_threaded}"

      @session_store = SessionStore.new(app: app,
                                        persistence_layer: persistence_layer,
                                        trans_handler: trans_handler,
                                        session_class: session_class,
                                        cookie_name: cookie_name,
                                        unknown_user: unknown_user,
                                        validator: validator,
                                        multi_threaded: multi_threaded) if false
      # @cleaner = run_cleaner if(self.class.const_get(:RUN_CLEANER))
      @admin_threads = ThreadGroup.new
      @async = ThreadGroup.new
      @app = app
      @system = persistence_layer
      @persistence_layer = persistence_layer
      @trans_handler = trans_handler
      @trans_handler ||= TransHandler.instance
      @session_class = session_class
      @session_class ||= SBSM::Session
      @expires = @session_class::EXPIRES
      @cookie_name = cookie_name
      @cookie_name ||=  @session_class::PERSISTENT_COOKIE_NAME
      @unknown_user = unknown_user
      @unknown_user ||= UNKNOWN_USER
      @validator = validator
      @cookie = Rack::Session::Cookie.new(self, :key => @cookie_name,  :expire_after =>  @expires,  :secret => 'secret')
#       use Rack::Session::Cookie, :key => rack_if.cookie_name, :expire_after =>  rack_if.expires,  :secret => secret

      @pool = Rack::Session::Pool.new(self)
    end

    def last_session
      @@last_session
    end
    def async(&block)
      @session_store.async(&block)
    end


    def call(env) ## mimick sbsm/lib/app.rb
      request = Rack::Request.new(env)
      response = Rack::Response.new
      if '/'.eql?(request.path)
        file_name = File.expand_path(File.join('doc', 'index.html'))
      else
        file_name = File.expand_path(File.join('doc', request.path))
      end
      if File.file?(file_name)
        mime_type = MimeMagic.by_extension(File.extname(file_name)).type
        SBSM.info "file_name is #{file_name} checkin base #{File.basename(file_name)} MIME #{mime_type}" if $VERBOSE
        response.set_header('Content-Type', mime_type)
        response.write(File.open(file_name, File::RDONLY){|file| file.read})
        return response
      end

      return [400, {}, []] if /favicon.ico/i.match(request.path)
      SBSM.debug "request session #{request.session.inspect} RACK_SESSION #{::Rack::RACK_SESSION} inspect  #{request.inspect}"
      session_id = nil
      unless request.session.empty?
        binding.pry
        session_id = request.session.id
        sid, sbsm_session =  @pool.find_session(request, session_id)
      else
        if request.cookies[@cookie_name]
          session_id = request.cookies[@cookie_name]
        else
          if REPEATABLE_SESSION_IDS
            $SBSM_app_session_id += 1
            session_id = sprintf('%016d', $SBSM_app_session_id)
          else
            session_id = rand((2**(0.size * 8 -2) -1)*10240000000000).to_s(16)
          end if false
        end
      #  sbsm_session = @session_class.new(app: @app, cookie_name: @cookie_name, trans_handler: @trans_handler, validator: @validator, unknown_user: @unknown_user)
      #   @pool.write_session(request, session_id, sbsm_session, {})
      end
      # old_id = session_id
      SBSM.debug "before find_session session_id #{session_id}"
      session_id, xx =  @pool.find_session(request, session_id)
      xx[:sbsm_session] ||= @session_class.new(app: @app, cookie_name: @cookie_name, trans_handler: @trans_handler, validator: @validator, unknown_user: @unknown_user)
      sbsm_session = xx[:sbsm_session]

      SBSM.debug "starting session_id #{session_id}  sbsm_session #{sbsm_session.class} #{request.path}: #{request.request_method} cookies #{@cookie_name} are #{request.cookies} @cgi #{@cgi.class}"
      @cgi = CGI.initialize_without_offline_prompt('html4') unless @cgi
      res = sbsm_session.process_rack(rack_request: request)
      SBSM.debug "starting session_id #{session_id} process_rack done"
      binding.pry if request.request_method.eql?('POST')
      options = {}
      response.write res
      response.headers['Content-Type'] ||= 'text/html; charset=utf-8'
      response.headers.merge!(sbsm_session.http_headers)
      if (result = response.headers.find { |k,v| /status/i.match(k) })
        response.status = result.last.to_i
        response.headers.delete(result.first)
      end
      SBSM.info(msg = "state #{sbsm_session.state.class} previous #{sbsm_session.state.previous.class}")
      puts msg
      @@counter ||=0
      @@counter += 1 if /fragment/i.match(request.path)
      binding.pry if @@counter > 1
      sbsm_session.cookie_input.each do |key, value|
        response.set_cookie(key, value)
      end
      response.set_cookie(SBSM::Session.get_cookie_name, session_id)
      @@last_session = sbsm_session
      if response.headers['Set-Cookie'].to_s.index(session_id)
        SBSM.debug "finish session_id.1 #{session_id}: matches response.headers['Set-Cookie'] headers #{response.headers}"
      else
        SBSM.debug "finish session_id.2 #{session_id}: headers #{response.headers}"
      end
      res = response.finish
      res
    end
  end
end
