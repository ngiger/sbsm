#!/usr/bin/env ruby
# TestSuite -- ydim -- 27.01.2005 -- hwyss@ywesee.com
require "simplecov"
puts "Running under ruby #{RUBY_VERSION}"

$: << File.dirname(File.expand_path(__FILE__))
SimpleCov.start do
  add_filter "/test/"
  add_filter "/gems/"
end
require "sbsm/logger"
Dir.foreach(File.dirname(__FILE__)) do |file|
  if /^test_.*\.rb$/o.match?(file)
    require file
  end
end
