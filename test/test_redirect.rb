#!/usr/bin/env ruby

$: << File.dirname(__FILE__)
$:.unshift File.expand_path("../lib", File.dirname(__FILE__))

ENV["RACK_ENV"] = "test"
ENV["REQUEST_METHOD"] = "GET"

require "minitest/autorun"
require "rack/test"
require "sbsm/app"
require "sbsm/session"
require "simple_sbsm"
require "nokogiri"

RUN_ALL_TESTS = true unless defined?(RUN_ALL_TESTS)

# Here we test, whether setting various class constant have the desired effect

class AppTestRedirect < Minitest::Test
  include Rack::Test::Methods
  attr_reader :app

  def setup
    @app = Demo::SimpleRackInterface.new
  end

  def test_session_redirect
    get "/de/page/redirect"
    skip("TODO: We should test redirect")
    assert_equal 303, last_response.status
    assert_equal "feedback", last_response.headers["Location"]
    assert_match REDIRECT_HTML_CONTENT, last_response.body
    assert_match(/utf-8/i, last_response.headers["Content-Type"])
  end
end
