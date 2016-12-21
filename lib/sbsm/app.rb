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
require 'cgi/drbsession'
require 'sbsm/drbserver'
require 'mimemagic'

module SBSM
  ###
  # App a base class for Webrick server
  class App < SBSM::DRbServer
    include DRbUndumped
    attr_reader :sbsm, :my_self, :trans_handler, :validator, :drb_uri

    OPTIONS = [ :app, :config_file, :trans_handler, :validator, :persistence_layer, :server_uri, :session, :unknown_user, :proxy ]
    OPTIONS.each{ |opt| eval "attr_reader :#{opt}" }

    # Base class for a SBSM based WebRick HTTP server
    # * offers a start_server() method to launch a DRB server for handling the DRB-requests
    # * offer a call(env) method form handling the WebRick requests
    # This is all what is needed to be compatible with WebRick
    #
    # === arguments
    #
    # * +app+ -               The app we should handle requests for
    # * +validator+ -         A Ruby class overriding the SBSM::Validator class
    # * +trans_handler+ -     A Ruby class overriding the SBSM::TransHandler class
    # * +persistence_layer+ - Persistence Layer to use
    # * +cookie_name+ -       The cookie to save persistent user data
    # * +drb_uri+ -           URI for DRB-Server of app
    #
    # === Examples
    # Look at steinwies.ch
    # * https://github.com/zdavatz/steinwies.ch (simple, mostly static files, one form, no persistence layer)
    #
    def initialize(app:, validator:, trans_handler:, drb_uri:, persistence_layer: nil, cookie_name: nil)
      SBSM.info "initialize #{$0} app #{app.class} @app is now #{@app.class} validator #{validator} th #{trans_handler} drb_uri #{drb_uri}"
      @app = app unless @app
      @cookie_name = cookie_name ||  SBSM::Session::PERSISTENT_COOKIE_NAME
      @drb_uri = drb_uri
      @trans_handler = trans_handler
      @validator = validator
      super(persistence_layer)
    end

    SESSION_ID = '_session_id'

    def call(env) ## mimick sbsm/lib/app.rb
      request = Rack::Request.new(env)
      response = Rack::Response.new
      if request.cookies[SESSION_ID] && request.cookies[SESSION_ID].length > 1
        session_id = request.cookies[SESSION_ID]
      else
        session_id = rand((2**(0.size * 8 -2) -1)*10240000000000).to_s(16)
      end
      file_name = File.expand_path(File.join('doc', request.path))
      if File.file?(file_name)
        mime_type = MimeMagic.by_extension(File.extname(file_name)).type
        SBSM.info "file_name is #{file_name} checkin base #{File.basename(file_name)} MIME #{mime_type}"
        response.set_header('Content-Type', mime_type)
        response.write(File.open(file_name, File::RDONLY){|file| file.read})
        return response
      end

      return [400, {}, []] if /favicon.ico/i.match(request.path)
      @drb_uri ||= @app.drb_uri
      args = {
        'database_manager'  =>  CGI::Session::DRbSession,
        'drbsession_uri'    =>  @drb_uri,
        'session_path'      =>  '/',
        @cookie_name => session_id,
      }
      SBSM.debug "starting session_id #{session_id} #{request.path}: cookies #{@cookie_name} are #{request.cookies} @session #{@session.class} @cgi #{@cgi.class}"
      @cgi = CGI.initialize_without_offline_prompt('html4') unless @cgi
      @session = CGI::Session.new(@cgi, args) unless @session
      saved = self[session_id]
      @start_time = Time.now.to_f
      GC.start
      SBSM.debug "GC.start took #{((Time.now.to_f)- @start_time)*1000.0} milliseconds"
      @proxy  = DRbObject.new(saved, server_uri) unless @proxy.is_a?(DRbObject)
      @proxy.trans_handler = @trans_handler
      @proxy.app = @app unless @proxy.app
      res = @proxy.drb_process(self, request)
      response.write res
      response.headers['Content-Type'] ||= 'text/html; charset=utf-8'
      response.headers.merge!(@proxy.http_headers)
      if (result = response.headers.find { |k,v| /status/i.match(k) })
        response.status = result.last.to_i
        response.headers.delete(result.first)
      end
      response.set_cookie(@cookie_name, :value =>  @proxy.cookie_input)
      response.set_cookie(SESSION_ID, :value => session_id)
      SBSM.debug "finish session_id #{session_id}: header with cookies #{response.headers} from #{@proxy.cookie_input}"
      response.finish
    end
  end
end
