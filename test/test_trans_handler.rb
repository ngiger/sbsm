#!/usr/bin/env ruby

# TestTransHandler -- sbsm -- 23.09.2004 -- hwyss@ywesee.com

$: << File.dirname(__FILE__)
$:.unshift File.expand_path("../lib", File.dirname(__FILE__))

require "minitest/autorun"
require "rack/request"
require "sbsm/trans_handler"
require "sbsm/logger"
require "cgi"
require "fileutils"

def fake_request_for_path(path = "/")
  Rack::Request.new(Rack::MockRequest.env_for("http://example.com:8080#{path}", {}))
end

module SBSM
  class TestTransHandler < Minitest::Test
    def setup
      @config_file = File.expand_path("../etc/trans_handler.yml", File.dirname(__FILE__))
    end

    def teardown
      FileUtils.rm_f(@config_file) if File.exist?(@config_file)
    end

    def test_parser_name
      assert_equal("uri", TransHandler.instance.parser_name)
    end

    def test_translate_uri
      request = fake_request_for_path "/"
      TransHandler.instance.translate_uri(request)
      assert_equal({}, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/fr"
      TransHandler.instance.translate_uri(request)
      assert_equal({"language" => "fr"}, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/en/"
      TransHandler.instance.translate_uri(request)
      assert_equal({"language" => "en"}, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/de/search/state_id/407422388/search_query/ponstan"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language"	=>	"de",
        "flavor" => "search",
        "event" => "state_id",
        "407422388" => "search_query",
        "ponstan" => ""
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/de/search/state_id/407422388/search_query/ponstan/page/4"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language"	=>	"de",
        "flavor" => "search",
        "event" => "state_id",
        "407422388" => "search_query",
        "ponstan" => "page",
        "4"	=>	""
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/de/search/pretty//state_id/407422388/search_query/ponstan/page/4"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language"	=>	"de",
        "flavor" => "search",
        "event" => "pretty",
        "" => "state_id",
        "407422388" => "search_query",
        "ponstan" => "page",
        "4" => ""
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/de/search/search_query/"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language"	=>	"de",
        "flavor" => "search",
        "event"	=>	"search_query"
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)
    end

    def test_translate_uri__shortcut
      assert_equal false, File.exist?(@config_file)
      request = fake_request_for_path "/shortcut"
      TransHandler.instance.translate_uri(request)
      assert_equal({}, request.params)
      assert_equal("/shortcut", request.uri)

      FileUtils.mkdir_p(File.dirname(@config_file))
      File.open(@config_file, "w") do |fh|
        fh.puts <<~EOS
          ---
          shortcut:
            /somewhere:
              over: the rainbow
              goodbye: yellow brick road
            /shortcut:
              shortcut: variables
        EOS
      end
      assert_equal true, File.exist?(@config_file)
      request = fake_request_for_path "/shortcut"
      # run in safe-mode
      Thread.new {
        # $SAFE = 1
        TransHandler.instance.translate_uri(request)
      }.join
      assert_equal({"shortcut" => "variables"}, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/somewhere"
      TransHandler.instance.translate_uri(request)
      expected = {
        "over"	=>	"the rainbow",
        "goodbye"	=>	"yellow brick road"
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)
    end

    def test_translate_uri_paths
      request = fake_request_for_path "/"
      TransHandler.instance.translate_uri(request)
      assert_equal({}, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/fr"
      TransHandler.instance.translate_uri(request)
      assert_equal({"language" => "fr"}, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/en/"
      TransHandler.instance.translate_uri(request)
      assert_equal({"language" => "en"}, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/en/flavor"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language" =>	"en",
        "flavor"	=>	"flavor"
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/en/other"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language" =>	"en",
        "flavor"	=>	"other"
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/de/gcc/search/state_id/407422388/search_query/ponstan"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language"	=>	"de",
        "flavor"	=>	"gcc",
        "event"	=>	"search",
        "state_id"	=>	"407422388",
        "search_query" =>	"ponstan"
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)
      request = fake_request_for_path "/de/gcc/search/state_id/407422388/search_query/ponstan/page/4"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language"	=>	"de",
        "flavor"	=>	"gcc",
        "event"	=>	"search",
        "state_id"	=>	"407422388",
        "search_query" =>	"ponstan",
        "page"	=>	"4"
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/de/gcc/search/pretty//state_id/407422388/search_query/ponstan/page/4"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language"	=>	"de",
        "flavor"	=>	"gcc",
        "event"	=>	"search",
        "pretty"	=>	"",
        "state_id"	=>	"407422388",
        "search_query" =>	"ponstan",
        "page"	=>	"4"
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)

      request = fake_request_for_path "/de/gcc/search/search_query/"
      TransHandler.instance.translate_uri(request)
      expected = {
        "language"	=>	"de",
        "flavor"	=>	"gcc",
        "event"	=>	"search",
        "search_query" =>	""
      }
      assert_equal(expected, request.params)
      assert_equal("/index.rbx", request.uri)
    end
  end
end
