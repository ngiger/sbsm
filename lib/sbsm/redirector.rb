#!/usr/bin/env ruby
# encoding: utf-8
#--
# Redirector -- sbsm -- 02.11.2006 -- hwyss@ywesee.com
#++
module SBSM
  module Redirector
    def http_headers
      binding.pry
      if(redirect?)
        SBSM.debug "reached Redirector::http_headers"
        @redirected = @state.redirected = true
        event, *args = @state.direct_event
        if(args.first.is_a? Hash)
          args = args.first
        end
        {
          "Location" => lookandfeel._event_url(event, args || {}),
        }
      else
        @redirected = @state.redirected = false
        super 
      end
    end
    def redirect?
      binding.pry
      direct = @state.direct_event
      if(direct.is_a?(Array))
        direct = direct.first
      end
      SBSM.debug "reached Redirector::redirect?"
      direct && (@request_method != 'GET' \
                 || ![direct, :sort].include?(event))
    end
    def to_html
      binding.pry
      if(redirect?)
        SBSM.debug "reached Redirector::to_html"
        ''
      else
        super
      end
    end
  end
end
