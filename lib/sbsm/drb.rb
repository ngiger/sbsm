#!/usr/bin/env ruby
# encoding: utf-8
#--
# DRb::DRbObject -- fix bug respond_to argument -- 22.08.2011 -- mhatakeyama@ywesee.com
# DRb::DRbObject -- fix bug in ruby -- 23.09.2005 -- hwyss@ywesee.com
#++
require 'drb'

module DRb
	class DRbObject
		def respond_to?(msg_id, *args)
			case msg_id
			when :_dump
				true
			when :marshal_dump
				false
			else
				method_missing(:respond_to?, msg_id)
			end
		end
	end
end
