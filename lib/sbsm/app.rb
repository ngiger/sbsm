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
# ngiger@ywesee.com
#
# App -- sbsm -- ngiger@ywesee.com
#++
require "cgi"
require "cgi/session"
require "sbsm/cgi"
require "sbsm/session_store"
require "sbsm/trans_handler"
require "sbsm/validator"
require "mimemagic"

module SBSM
  ###
  # App as a member of session
  class App
    attr_reader :unknown_user

    def initialize
      SBSM.info "initialize"
    end
  end

  class RackInterface
    attr_accessor :session # thread variable!
    attr_reader :session_store, :unknown_user
    SESSION_ID = "_session_id"

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
      trans_handler: nil,
      session_class: nil,
      persistence_layer: nil,
      unknown_user: nil,
      cookie_name: nil,
      multi_threaded: nil)
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
        multi_threaded: multi_threaded)
      @unknown_user = unknown_user
    end

    def last_session
      @@last_session
    end

    def fix_html_content_type(content_type)
      # davaz.com#50
      if content_type == "application/xhtml+xml"
        return "text/html; charset=utf-8"
      end
      content_type
    end

    def call(env) ## mimick sbsm/lib/app.rb
      request = Rack::Request.new(env)
      response = Rack::Response.new
      session_id = if request.cookies[SESSION_ID] && request.cookies[SESSION_ID].length > 1
        request.cookies[SESSION_ID]
      else
        rand((2**(0.size * 8 - 2) - 1) * 10240000000000).to_s(16)
      end
      file_name = if "/".eql?(request.path)
        File.expand_path(File.join("doc", "index.html"))
      else
        File.expand_path(File.join("doc", request.path))
      end
      if File.file?(file_name)
        mime_type = if File.extname(file_name).length > 0 && (mime_info = MimeMagic.by_extension(File.extname(file_name)))
          mime_info.type
        else
          MimeMagic.by_path(file_name)
        end
        mime_type ||= "text/plain"
        mime_type = fix_html_content_type(mime_type)
        SBSM.debug "file_name is #{file_name} checkin base #{File.basename(file_name)} MIME #{mime_type}"
        response.set_header("Content-Type", mime_type)
        response.write(File.open(file_name, File::RDONLY) { |file| file.read })
        return response.finish
      end

      return [400, {}, []] if /favicon.ico/i.match?(request.path)
      Thread.current.thread_variable_set(:session, @session_store[session_id])
      session = Thread.current.thread_variable_get(:session)
      SBSM.debug "starting session_id #{session_id}  session #{session.class} #{request.path}: cookies #{@cookie_name} are #{request.cookies} @cgi #{@cgi.class}"
      res = session.process_rack(rack_request: request)
      thru = session.get_passthru
      if thru.size > 0
        begin
          file_name = thru.first
          raise Errno::ENOENT unless File.exist?(file_name)
          response.set_header("Content-Type", fix_html_content_type(MimeMagic.by_extension(File.extname(file_name)).type))
          response.headers["Content-Disposition"] = "#{thru.last}; filename=#{File.basename(file_name)}"
          response.headers["Content-Length"] = File.size(file_name).to_s
          response.write(File.open(file_name, File::RDONLY) { |file| file.read })
        rescue Errno::ENOENT, IOError => err
          error_msg = "#{file_name} Not found\n"
          SBSM.error("#{err.message} #{thru.first} => #{error_msg}")
          return [404, {"Content-Type" => "text/html", "Content-Length" => error_msg.size.to_s}, [error_msg]]
        end
      else
        response.write res unless request.request_method.eql?("HEAD")
        response.headers["Content-Type"] ||= "text/html; charset=utf-8"
        response.headers.merge!(session.http_headers)
      end

      if (result = response.headers.find { |k, v| /status/i.match(k) })
        response.status = result.last.to_i
        response.headers.delete(result.first)
      end
      response.set_cookie(session.persistent_cookie_name,
        {value: session.cookie_pairs,
         path: "/",
         expires: (Time.now + (60 * 60 * 24 * 365 * 10))})
      response.set_cookie(SESSION_ID, {value: session_id, path: "/", expires: (Time.now + (60 * 60 * 24 * 365 * 10))})
      # bad idea to reset rack_request if we need more page
      @@last_session = session
      if response.headers["Set-Cookie"].to_s.index(session_id)
        SBSM.debug "finish session_id.1 #{session_id}: matches response.headers['Set-Cookie'] #{response.headers["Set-Cookie"]}"
      else
        SBSM.debug "finish session_id.2 #{session_id}: headers #{response.headers}"
      end
      response.status = 302 if response.headers["Location"]
      response.finish
    end

    private_class_method

    def self.last_session  # for unit tests only
      @@last_session
    end
  end
end
