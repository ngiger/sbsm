#!/usr/bin/env ruby

#--
# State Based Session Management
# Copyright (C) 2016 Niklaus Giger
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
# ngiger@ywesee.com
#++

require "logger"
require "sbsm/version"
module SBSM
  @@logger = Logger.new($stderr)
  @@logger.level = Logger::WARN
  def self.logger=(logger)
    @@logger = logger
  end

  def self.logger
    @@logger
  end

  # a simple logger, which makes it easy to compare the timing of the entries
  # by the different process. Should probably later be replaced by a Rack based logger
  def self.info(msg)
    info = "#{File.basename(caller(1..1).first)} #{msg}"
    @@logger&.info(info)
  end

  def self.error(msg)
    info = "#{File.basename(caller(1..1).first)} #{msg}"
    @@logger&.error(info)
  end

  def self.warn(msg)
    info = "#{File.basename(caller(1..1).first)} #{msg}"
    @@logger&.warn(info)
  end

  def self.debug(msg)
    info = "#{File.basename(caller(1..1).first)} #{msg}"
    @@logger&.debug(info)
  end
end
