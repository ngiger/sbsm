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
# Request -- sbsm -- hwyss@ywesee.com

require 'sbsm/cgi'
require 'cgi/session'
require 'cgi/drbsession'
require 'drb/drb'
require 'delegate'

module SBSM
  class Request < SimpleDelegator
    include DRbUndumped
    attr_reader :cgi
    def initialize(drb_uri, html_version = "html4")
      @cgi = CGI.new(html_version)
			@drb_uri = drb_uri
			#@server = Apache.request.server if defined?(Apache)
			@thread = nil
			super(@cgi)
    end
		def abort
			@thread.exit
		end
		def passthru(path)
			@passthru = path
			''
		end
=begin
			req = Apache.request
			req.server.log_notice("passthru")
			begin
				req.server.log_notice(path)
				File::open( path ) { |ofh|
					req.log_reason(path, ofh)
					req.send_fd(ofh)
				}
				req.server.log_notice(done)
				''
			rescue IOError => err
				req.log_reason( err.message, path)
				Apache::NOT_FOUND
			end
		end
=end
		def process
			begin
				@thread = Thread.new {
					Thread.current.priority=10
					server = Apache.request.server if defined?(Apache)
					server.log_notice("#{id} - sending request")
					drb_request()
					server.log_notice("#{id} - getting response")
					drb_response()
					server.log_notice("#{id} - done")
				}	
				@thread.join
			rescue StandardError => e
				handle_exception(e)
			ensure
				@session.close if @session.respond_to?(:close)
			end
		end
		private
		def drb_request
			@session = CGI::Session.new(@cgi,
				'database_manager'	=>	CGI::Session::DRbSession,
				'drbsession_uri'		=>	@drb_uri,
				'session_path'			=>	'/')
			@proxy = @session[:proxy]
			@proxy.process(self)
		end
		def drb_response
			res = ''
			while(snip = @proxy.next_html_packet)
				res << snip
			end
			# view.to_html can call passthru instead of sending data
			if(@passthru) 
				Apache.request.internal_redirect(@passthru)
			else
				begin
					@cgi.out(@proxy.http_headers) { 
						(@cgi.params.has_key?("pretty")) ? CGI.pretty( res ) : res
					}
				rescue StandardError => e
					handle_exception(e)
				end
			end
		end
		def handle_exception(e)
			if defined?(Apache)
				msg = [
					[Time.now, id, e.class].join(' - '),
					e.message,
					e.backtrace,
				].flatten.join("\n")
				Apache.request.server.log_error(msg)
			end
			hdrs = {
				'Status' => '302 Moved', 
				'Location' => '/resources/errors/appdown.html',
			}
			@cgi.header(hdrs)
			@thread.exit 
			@proxy.active_thread.exit if @proxy
		end
  end
end