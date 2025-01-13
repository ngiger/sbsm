#!/usr/bin/env ruby

#--
# SBSM::TransHandler -- sbsm -- 25.01.2012 -- mhatakeyama@ywesee.com
# SBSM::TransHandler -- sbsm -- 23.09.2004 -- hwyss@ywesee.com
#++

require "cgi"
require "singleton"
require "yaml"
require "rack"
module Rack
  class Request
    attr_accessor :uri # monkey patch for Rack::Request
  end
end

module Apache
  DECLINED = -1 unless defined?(DECLINED)
end

module SBSM
  class AbstractTransHandler
    # * +parser_name+  -      Name defaults to 'uri'
    attr_reader :parser_name
    # * +config_file+ -       Full path of YAML configuration file for shortcuts
    attr_reader :config_file
    # * +handler_uri+ -       The handler file to be used
    attr_reader :handler_uri
    @@empty_check ||= nil
    @@lang_check ||= nil
    @@uri_parser ||= nil

    #
    # === arguments
    #
    # * +name+ -              Used for checking whether a 'name'.grammar or
    #   'name'_parser.rb can be loaded
    # * +config_file+ -       Where the config file can be found. Default to 'etc/trans_handler.yml'
    # * +handler_ur+ -        The handler to be invoked. defaults to '/index.rbx'
    #
    def initialize(name: nil, config_file: nil, handler_uri: nil)
      @handler_uri = handler_uri
      @handler_uri ||= "/index.rbx"
      config_file ||= "etc/trans_handler.yml"
      @config_file = File.expand_path(config_file)
      @parser_name = name ||= "uri"
      @parser_method = "_#{name}_parser"
      @grammar_path = File.expand_path("../../data/#{name}.grammar",
        File.dirname(__FILE__))
      @parser_path = File.expand_path("#{name}_parser.rb",
        File.dirname(__FILE__))
    end

    def config(request)
      config = Hash.new { {} }
      begin
        return config unless @config_file && File.exist?(@config_file)
        config.update(YAML.load_file(@config_file))
        config
      rescue
        puts "Unable to load url configuration: %s", @config_file
        puts "Hint: store configuration in a YAML-File"
        config
      end
    end

    # * +request+ -    A Rack::Request with our monkey patch to access :uri
    # * +config+ -     config values for shortcuts (Hash of Hash)
    def handle_shortcut(request, config)
      if (params = config["shortcut"][request.path])
        params.each do |key, val|
          request.params[key.to_s] = val || ""
        end
        request.uri = @handler_uri
      end
    end

    # * +uri+ - uri to be parsed, e.g. /language/flavor/event/key/value/key/value/...
    #
    # language, flavor and event are added as special keys, else
    # values are inserted as string
    def simple_parse(uri)
      values = {}
      items = uri.split("/")
      items.shift
      lang = items.shift
      values.store(:language, lang) if lang
      flavor = items.shift
      values.store(:flavor, flavor) if flavor
      event = items.shift
      values.store(:event, event) if event
      until items.empty?
        key = items.shift
        value = items.shift
        values.store(key, value)
      end
      values
    end

    # * +request+ -    A Rack::Request with our monkey patch to access :uri
    def simple_parse_uri(request)
      # values = request.params
      simple_parse(request.path).each do |key, value|
        request.env[key.to_s] = value || ""
        request.update_param(key.to_s, CGI.unescape(value.to_s))
      end
    end

    # The default parser for an URI
    # === arguments
    # * +request+ -    A Rack::Request with our monkey patch to access :uri
    def parse_uri(request)
      @uri_parser ||= uri_parser
      ast = @uri_parser.parse(request.path)
      request.params
      ast.children_names.each { |name|
        case name
        when "language", "flavor", "event", "zone"
        # 					values.add(name, ast.send(name).value)
        when "variables"
          ast.variables.each { |pair|
            key = pair.key.value
            val = if pair.children_names.include?("value")
              CGI.unescape(pair.value.value.to_s)
            else
              ""
            end
            request.update_param(key, val)
          }
        end
      }
    end

    # * +request+ -    A Rack::Request with our monkey patch to access :uri
    def translate_uri(request)
      @@empty_check ||= Regexp.new("^/?$")
      @@lang_check ||= Regexp.new("^/[a-z]{2}(/|$)")
      uri = request.path
      request.uri ||= uri
      config = config(request)
      handle_shortcut(request, config)
      case uri
      when @@empty_check
        request.uri = config["redirect"]["/"] ||= @handler_uri
      when @@lang_check
        begin
          parse_uri(request)
        rescue LoadError # this happens often
          simple_parse_uri(request)
        end
        request.uri = @handler_uri
      end
      Apache::DECLINED
    end

    def uri_parser(grammar_path = @grammar_path, parser_path = @parser_path)
      if File.exist?(grammar_path)
        oldpath = File.expand_path("_" + File.basename(grammar_path),
          File.dirname(grammar_path))
        src = File.read(grammar_path)
        unless File.exist?(oldpath) && File.read(oldpath) == src
          File.delete(oldpath) if File.exist?(oldpath)
          Parse.generate_parser_from_file_to_file(grammar_path,
            parser_path, @parser_method, "SBSM")
          File.open(oldpath, "w") { |f| f << src }
        end
      end
      require parser_path
      SBSM.send(@parser_method)
    end
  end

  class TransHandler < AbstractTransHandler
    include Singleton
  end
end
