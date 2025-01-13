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
# TestValidator -- sbsm -- 15.11.2002 -- hwyss@ywesee.com

$: << File.dirname(__FILE__)
$: << File.expand_path("../lib", File.dirname(__FILE__))

require 'minitest/autorun'
require 'sbsm/validator'

class Validator < SBSM::Validator
	attr_accessor :errors
	DATES = [
		:date
	]
	ENUMS = {
		:enum	=>	['foo'],
		:values =>	['1', '2', '3', '4', '7'],
	}
	EVENTS = [
		:logout,
	]
	BOOLEAN = [ :bool ]
	PATTERNS = {
		:pattern =>	/(^\d+$)|(^[a-z]{1,3}$)/,
	}
  HTML = [ :html ]
end

class TestValidator < Minitest::Test
  def setup
    @val = Validator.new
  end
	def test_reset_errors
		assert_equal({}, @val.errors)
		@val.errors = {:foo=>:bar}
    @val.reset_errors
		assert_equal({}, @val.errors)
	end
	def test_validate
		assert_nil(@val.validate(:something, :other) )
	end
	def test_boolean
		assert_equal(true, @val.validate(:bool, 'true'))
		assert_equal(true, @val.validate(:bool, 'TRUE'))
		assert_equal(true, @val.validate(:bool, 1))
		assert_equal(true, @val.validate(:bool, true))
		assert_equal(true, @val.validate(:bool, 'Y'))
		assert_equal(true, @val.validate(:bool, 'j'))
		assert_equal(false, @val.validate(:bool, 'false'))
		assert_equal(false, @val.validate(:bool, 'FALSE'))
		assert_equal(false, @val.validate(:bool, 0))
		assert_equal(false, @val.validate(:bool, false))
		assert_equal(false, @val.validate(:bool, 'N'))
	end
	def test_enum
		assert_equal('foo', @val.validate(:enum, 'foo'))
	end
	def test_event
		assert_equal(:logout, @val.validate(:event, 'logout'))
		assert_equal(:logout, @val.validate(:event, ['logout']))
	end
  def test_InvalidDataError
    tst=[]; 0.upto(1000).each{|x| tst << x}
    key = 'key: ' +tst.join(',')
    value = SBSM::InvalidDataError.new(:dummy, key, 'value: '+ tst.join(';'))
    max_length = 200
    assert(key.size >= max_length)
    assert(value.to_s.size < max_length, "InvalidDataError must limit output to less < #{max_length} chars. actual #{value.to_s.size }")
  end
	def test_email1
		assert_equal('e_invalid_email_address email test', @val.validate(:email, 'test').message)
		assert_equal('test@com', @val.validate(:email, 'test@com'))
		assert_equal('test@test.com', @val.validate(:email, 'test@test.com'))
		assert_equal(SBSM::InvalidDataError, @val.validate(:email, 'test@test@test').class)
	end
	def test_pass
		assert_equal('098f6bcd4621d373cade4e832627b4f6', @val.validate(:pass, 'test'))
	end
	def test_valid_values
		expected = ['1', '2', '3', '4', '7']
		assert_equal(expected, @val.valid_values(:values))
		assert_equal(expected, @val.valid_values('values'))
	end
	def test_date
		assert_equal(Date.new(2002,1,2), @val.validate(:date, '2.1.2002'))
		assert_equal(SBSM::InvalidDataError, @val.validate(:date, '13.13.1234').class)
		assert_nil(@val.validate(:date, " \t"))
	end
	def test_state_id
		assert_nil(@val.validate(:state_id, nil))
		assert_nil(@val.validate(:state_id, "df"))
		assert_equal(1245, @val.validate(:state_id, "1245"))
		assert_equal(-1245, @val.validate(:state_id, "-1245"))
	end
	def test_pattern
		assert_equal('new', @val.validate(:pattern, 'new'))
		assert_equal('12345', @val.validate(:pattern, '12345'))
		assert_nil(@val.validate(:pattern, '23foo45'))
		assert_nil(@val.validate(:pattern, 'abfoodc'))
	end
  def test_validate_html
    src = "<SPAN style=\"PADDING-BOTTOM: 4px; LINE-HEIGHT: 1.4em; WHITE-SPACE: normal\"><p class=\"MsoNormal\" style=\"MARGIN: 0cm -0.3pt 0pt 0cm; TEXT-ALIGN: justify\"><span lang=\"DE\" style=\"FONT-SIZE: 11pt; FONT-FAMILY: Arial; mso-bidi-font-size: 10.0pt; mso-bidi-font-family: 'Times New Roman'\">Wirkstoff: Ibuprofenum. </span></p><p class=\"MsoNormal\" style=\"MARGIN: 0cm -0.3pt 0pt 0cm; TEXT-ALIGN: justify\"><span lang=\"DE\" style=\"FONT-SIZE: 11pt; FONT-FAMILY: Arial; mso-bidi-font-size: 10.0pt; mso-bidi-font-family: 'Times New Roman'\">Hilfsstoffe: Conserv.: Sorbinsäure (E 200)</span></p></span>"
    expected = "<span style=\"padding-bottom: 4px; line-height: 1.4em; white-space: normal\"><p class=\"msonormal\" style=\"margin: 0cm -0.3pt 0pt 0cm; text-align: justify\"><span lang=\"de\" style=\"font-size: 11pt; font-family: arial; mso-bidi-font-size: 10.0pt; mso-bidi-font-family: 'times new roman'\">wirkstoff: ibuprofenum. </span></p><p class=\"msonormal\" style=\"margin: 0cm -0.3pt 0pt 0cm; text-align: justify\"><span lang=\"de\" style=\"font-size: 11pt; font-family: arial; mso-bidi-font-size: 10.0pt; mso-bidi-font-family: 'times new roman'\">hilfsstoffe: conserv.: sorbinsäure (e 200)</span></p></span>"
	res = @val.validate(:html, src)
    assert_equal expected, res.downcase.sub("\n", '')
    assert_match('Wirkstoff: Ibuprofenum. ', res)
    assert_match('Hilfsstoffe: Conserv.: Sorbinsäure (E 200)', res)
  end
  def test_validate_html_pre
    src = "<pre>     fooo     </pre>"
    expected = "<pre>     fooo     </pre>"
    assert_equal expected, @val.validate(:html, src)
  end
end
