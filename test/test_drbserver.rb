#!/usr/bin/env ruby
# encoding: utf-8
#
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
# hwyss@ywesee.com
#
# TestDRbServer -- ODDB -- 27.11.2003 -- hwyss@ywesee.com


$: << File.dirname(__FILE__)
$: << File.expand_path('../lib', File.dirname(__FILE__))

require 'minitest/autorun'
require 'sbsm/drbserver'

class TestDRbServer < Minitest::Test
	class DRbServer < ::SBSM::DRbServer
		attr_reader :sessions
		CAP_MAX_THRESHOLD = 3
		MAX_SESSIONS = 3
	end
	def setup
		@server = DRbServer.new
	end
	def test_session
		ses1 = @server['test1']
		assert_instance_of(SBSM::Session, ses1)
		assert_equal({'test1'=>ses1}, @server.sessions)
		ses2 = @server['test2']
		assert_instance_of(SBSM::Session, ses2)
		refute_equal(ses1, ses2)
		expected = {
			'test1'	=>	ses1,
			'test2'	=>	ses2,
		}
		assert_equal(expected, @server.sessions)
		ses3 = @server['test3']
		assert_instance_of(SBSM::Session, ses3)
		refute_equal(ses1, ses3)
		refute_equal(ses2, ses3)
		expected = {
			'test1'	=>	ses1,
			'test2'	=>	ses2,
			'test3'	=>	ses3,
		}
		assert_equal(expected, @server.sessions)
		ses4 = @server['test4']
		assert_instance_of(SBSM::Session, ses4)
		refute_equal(ses1, ses4)
		refute_equal(ses2, ses4)
		expected = {
			'test2'	=>	ses2,
			'test3'	=>	ses3,
			'test4'	=>	ses4,
		}
		@server.cap_max_sessions
		assert_equal(expected, @server.sessions)
		ses2.touch
		ses5 = @server['test5']
		assert_instance_of(SBSM::Session, ses5)
		expected = {
			'test2'	=>	ses2,
			'test4'	=>	ses4,
			'test5'	=>	ses5,
		}
	end
end
