# encoding: utf-8
#--
# DRbSession - CGI::Session session database manager using DRb.
# Copyright (C) 2001 by Tietew. All Rights Reserved.
#++
require 'drb/drb'
require 'sbsm/logger'
class CGI
  class Session
    class DRbSession
      attr_reader :obj
      def initialize(session, option={})
        unless uri = option['drbsession_uri']
          raise ArgumentError, "drbsession_uri not specified"
        end
        
        unless DRb.thread
          DRb.start_service
        end
        
        holder = DRbObject.new(nil, uri)
        @obj = holder[session.session_id]
      end
      
      def restore
        @obj.restore
      end
      def update
        @obj.update
      end
      def close
        @obj.close
      end
      def delete
        @obj.delete
      end
    end
  end
end
