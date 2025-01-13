#!/usr/bin/env ruby

#--
# Turing -- SBSM -- 15.05.2009 -- hwyss@ywesee.com
#++
# Use a Hash instead of a PStore to manage Captchas
require "turing"

module SBSM
  class PStore < Hash
    def initialize *args
      super
      @mutex = Mutex.new
    end

    def transaction &block
      @mutex.synchronize(&block)
    end
  end
end

class Turing::Challenge
  alias_method :__orig_initialize__, :initialize
  def initialize *args
    __orig_initialize__(*args)
    @store = SBSM::PStore.new
  end
end
