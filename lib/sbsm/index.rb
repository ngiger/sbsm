#!/usr/bin/env ruby

#--
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
# Index -- sbsm -- 04.03.2003 -- hwyss@ywesee.com
#++

module SBSM
  class Index
    def initialize
      @values = []
      @children = []
    end

    def delete(key, value)
      if key.size == 0
        @values.delete(value)
      elsif (child = @children.at(key[0].ord))
        child.delete(key[1..], value)
      end
    end

    def fetch(key)
      if key.size == 1
        @values + @children[key[0].ord].to_a
      elsif key.size > 1 && @children.at(key[0].ord)
        @children.at(key[0].ord)[key[1..]]
      else
        []
      end
    end

    def replace(oldkey, newkey, value)
      delete(oldkey, value)
      store(newkey, value)
    end

    def store(key, *values)
      if key.size == 0
        @values += values
      else
        @children[key[0].ord] ||= self.class.new
        @children.at(key[0].ord).store(key[1..], *values)
      end
    end

    def to_a
      @values + @children.inject([]) { |inj, child| inj + child.to_a.compact }
    end
    alias_method :[], :fetch
    alias_method :[]=, :store
  end
end
