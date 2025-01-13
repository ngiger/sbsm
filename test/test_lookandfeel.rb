#!/usr/bin/env ruby

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
# TestLookandfeel -- sbsm -- 15.11.2002 -- hwyss@ywesee.com
require "minitest/autorun"
require "sbsm/lookandfeel"
require "date"
require "sbsm/lookandfeelwrapper"

class StubLookandfeelState
  attr_reader :direct_event
  def initialize(direct_event)
    @direct_event = direct_event
  end
end

class StubLookandfeelSession
  attr_accessor :user_input, :state,
    :is_crawler
  DEFAULT_LANGUAGE = "de"
  def initialize(*args)
    @persistent_user_input = {}
    @is_crawler = nil
    @user_input = nil
  end

  def default_language
    "de"
  end

  def is_crawler?
    !!@is_crawler
  end

  def language
    persistent_user_input(:language) \
      || self.class::DEFAULT_LANGUAGE
  end

  def navigation
    [
      StubLookandfeelState.new(:foo),
      StubLookandfeelState.new(:bar),
      StubLookandfeelState.new(:baz)
    ]
  end

  def persistent_user_input(key)
    if (value = @user_input)
      @persistent_user_input.store(key, value)
    else
      @persistent_user_input[key]
    end
  end

  def flavor
    "gcc"
  end

  def server_port
    "1234"
  end

  def server_name
    "test.com"
  end

  def http_protocol
    "http"
  end
end

class StubNotBuiltIn
end

class LookandfeelBase < SBSM::Lookandfeel
  HTML_ATTRIBUTES = {
    stub: {foo: "Bar", baz: 123, rof: StubNotBuiltIn}
  }
  RESOURCES = {
    foo: "bar"
  }

  DICTIONARIES = {
    "de"	=>	{
      date_format: "%d.%m.%Y",
      foo: "dictbar",
      from_file: txt_file("lnf_file.txt"),
      from_file_mac: txt_file("mac_file.txt"),
      from_file_dos: txt_file("dos_file.txt")
    },
    "fr"	=>	{
      foo: "frabar"
    }
  }
  TXT_RESOURCES = File.expand_path("data", File.dirname(__FILE__))
end

class LookandfeelWrapper1 < SBSM::LookandfeelWrapper
  HTML_ATTRIBUTES = {
    stub: {foo: "baz"}
  }
  ENABLED = [:foo, :bar, :bof]
  RESOURCES = {
    foo: "foo"
  }
end

class LookandfeelWrapper2 < SBSM::LookandfeelWrapper
  ENABLED = [:baz]
end

class TestLookandfeel < Minitest::Test
  def setup
    @session = StubLookandfeelSession.new
    @lookandfeel = LookandfeelBase.new(@session)
  end

  def test_attributes
    expected = {foo: "Bar", baz: 123, rof: StubNotBuiltIn}
    assert_equal(expected, @lookandfeel.attributes(:stub))
  end

  def test_no_attributes
    assert_equal({}, @lookandfeel.attributes(:undefined))
  end

  def test_resource
    assert_equal("http://test.com:1234/resources/gcc/bar", @lookandfeel.resource(:foo))
  end

  def test_lookup
    assert_equal("dictbar", @lookandfeel.lookup(:foo))
  end

  def test_lookup2
    assert_equal("This text looked up from File<br>With a newline", @lookandfeel.lookup(:from_file))
  end

  def test_lookup3
    assert_equal("This mac text looked up from File<br>With a newline", @lookandfeel.lookup(:from_file_mac))
  end

  def test_lookup4
    assert_equal("This dos text looked up from File<br>With a newline", @lookandfeel.lookup(:from_file_dos))
  end

  def test_lookup5
    session = StubLookandfeelSession.new
    session.user_input = "fr"
    lookandfeel2 = LookandfeelBase.new(session)
    assert_equal("frabar", lookandfeel2.lookup(:foo))
  end

  def test_lookup6
    session = StubLookandfeelSession.new
    session.user_input = "fr"
    lookandfeel2 = LookandfeelBase.new(session)
    assert_equal("%d.%m.%Y", lookandfeel2.lookup(:date_format))
  end

  def test_rfc1123
    Time.gm(2002, 11, 20, 9, 45, 23)
    time = Time.local(2002, 11, 20, 9, 45, 23)
    expected = "Wed, 20 Nov 2002 #{sprintf("%02d", 9 - time.gmt_offset / 3600)}:45:23 UTC"
    assert_equal(expected, time.rfc1123)
  end

  def test_base_url
    assert_equal("http://test.com:1234/de/gcc", @lookandfeel.base_url)
  end

  def test_event_url
    assert_match(/http:\/\/test.com:1234\/de\/gcc\/foo\/state_id\/\d\/bar\/baz/, @lookandfeel.event_url(:foo, {bar: "baz"}))
  end

  def test_event_url__crawler
    @session.is_crawler = true
    assert_equal("http://test.com:1234/de/gcc/foo/bar/baz",
      @lookandfeel.event_url(:foo, {bar: "baz"}))
  end

  def test_event_url__state_id_given
    assert_equal("http://test.com:1234/de/gcc/foo/bar/baz/state_id/mine",
      @lookandfeel.event_url(:foo, [:bar, "baz", :state_id, "mine"]))
  end

  def test_format_price
    assert_equal("123.45", @lookandfeel.format_price(12345))
    assert_nil(@lookandfeel.format_price(nil))
    assert_nil(@lookandfeel.format_price(0))
  end

  def test_format_date
    hannesgeburtstag = Date.new(1975, 8, 21)
    expected = "21.08.1975"
    assert_equal(expected, @lookandfeel.format_date(hannesgeburtstag))
  end

  def test_languages
    assert_equal(["de", "fr"], @lookandfeel.languages)
  end
end

class TestLookandfeelWrapper < Minitest::Test
  def setup
    @lookandfeel = LookandfeelBase.new(StubLookandfeelSession.new)
    @wrapped = LookandfeelWrapper1.new(@lookandfeel)
  end

  def test_navigation1
    lnf = SBSM::LookandfeelWrapper.new(@lookandfeel)
    assert_equal([], lnf.navigation)
  end

  def test_navigation2
    nav = @wrapped.navigation
    result = nav.collect { |st| st.direct_event }
    assert_equal([:foo, :bar], result)
  end

  def test_navigation3
    lnf = LookandfeelWrapper2.new(@wrapped)
    nav = lnf.navigation
    result = nav.collect { |st| st.direct_event }
    assert_equal([:foo, :bar, :baz], result)
  end

  def test_flavor
    assert_equal("gcc", @wrapped.flavor)
  end

  def test_resource1
    lnf = SBSM::LookandfeelWrapper.new(@lookandfeel)
    assert_equal("http://test.com:1234/resources/gcc/bar", lnf.resource(:foo))
  end

  def test_resource2
    assert_equal("http://test.com:1234/resources/gcc/foo", @wrapped.resource(:foo))
  end

  def test_attributes1
    lnf = SBSM::LookandfeelWrapper.new(@lookandfeel)
    expected = {foo: "Bar", baz: 123, rof: StubNotBuiltIn}
    assert_equal(expected, lnf.attributes(:stub))
  end

  def test_attributes2
    expected = {foo: "baz"}
    assert_equal(expected, @wrapped.attributes(:stub))
  end
end
