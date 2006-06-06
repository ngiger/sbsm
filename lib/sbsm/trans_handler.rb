#!/usr/bin/env ruby
# TransHandler -- sbsm -- 23.09.2004 -- hwyss@ywesee.com

require 'rockit/rockit'
require 'cgi'
require 'singleton'
require 'yaml'

module SBSM
	class AbstractTransHandler
		attr_reader :parser_name
		CONFIG_PATH = '../etc/trans_handler.yml'
		@@empty_check ||= nil
		@@lang_check ||= nil
		@@uri_parser ||= nil
		HANDLER_URI = '/index.rbx'
		def initialize(name)
			@parser_name = name
			@parser_method = "_#{name}_parser"
			@grammar_path = File.expand_path("../../data/#{name}.grammar", 
				File.dirname(__FILE__))
			@parser_path = File.expand_path("#{name}_parser.rb", 
				File.dirname(__FILE__))
		end
    def config(request)
      config = Hash.new { {} } 
			begin
        path = File.expand_path(CONFIG_PATH, request.server.document_root)
        path.untaint
        config.update(YAML.load(File.read(path)))
        config
			rescue StandardError => err
				fmt = 'Unable to load url configuration: %s'
				request.server.log_warn(fmt, err.message)
				fmt = 'Hint: store configuration in a YAML-File at DOCUMENT_ROOT/%s'
				request.server.log_notice(fmt, CONFIG_PATH)
        config
			end
    end
		def handle_shortcut(request, config)
			if(notes = config['shortcut'][request.uri])
				notes.each { |key, val|
					request.notes.add(key, val)
				}
				request.uri = HANDLER_URI
			end
		end
		def parse_uri(request)
			@uri_parser ||= self.uri_parser 
			ast = @uri_parser.parse(request.uri)
			values = request.notes
			ast.children_names.each { |name|
				case name
				when'language', 'flavor', 'event', 'zone'
					values.add(name, ast.send(name).value)
				when 'variables'
					ast.variables.each { |pair|
						key = pair.key.value
						val = if(pair.children_names.include?('value'))
							CGI.unescape(pair.value.value.to_s)
						else
							''
						end
						values.add(key, val)
					}
				end
			}
		end
		def translate_uri(request)
			@@empty_check ||= Regexp.new('^/?$')
			@@lang_check ||= Regexp.new('^/[a-z]{2}(/|$)')
      config = config(request)
      handle_shortcut(request, config)
      uri = request.uri
      case uri
      when @@empty_check
        request.uri = config['redirect']['/'] || HANDLER_URI
      when @@lang_check
        self.parse_uri(request)
        request.uri = HANDLER_URI
      end
      Apache::DECLINED
		end
		def uri_parser(grammar_path=@grammar_path, parser_path=@parser_path)
			if(File.exist?(grammar_path))
				oldpath = File.expand_path("_" << File.basename(grammar_path), 
					File.dirname(grammar_path))
				src = File.read(grammar_path)
				unless(File.exists?(oldpath) && File.read(oldpath)==src)
					File.delete(oldpath) if File.exists?(oldpath)
					Parse.generate_parser_from_file_to_file(grammar_path, 
						parser_path, @parser_method, 'SBSM')
					File.open(oldpath, 'w') { |f| f << src }
				end
			end
			require parser_path
			SBSM.send(@parser_method)
		end
	end
	class TransHandler < AbstractTransHandler
		include Singleton
		def initialize
			super('uri')
		end
	end
	class FlavoredTransHandler < AbstractTransHandler
		include Singleton
		def initialize
			super('flavored_uri')
		end
	end
	class ZoneTransHandler < AbstractTransHandler
		include Singleton
		def initialize
			super('zone_uri')
		end
	end
end
