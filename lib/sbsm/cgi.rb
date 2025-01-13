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
#++
# CGI redefinitions

require "cgi"

class CGI
  # Lets satisfy cgi-offline prompt, even if request does not have
  # REQUEST_METHOD. (It must be mostly for test purpose).
  # See http://ruby-doc.org/stdlib-2.3.1/libdoc/cgi/rdoc/CGI.html#method-c-new
  def self.initialize_without_offline_prompt(*args)
    cgi_input = true
    unless ENV.has_key?("REQUEST_METHOD")
      cgi_input = false
      ENV["REQUEST_METHOD"] = "GET"
    end
    cgi = CGI.new(*args)
    unless cgi_input
      ENV.delete("REQUEST_METHOD")
    end
    cgi
  end
end
