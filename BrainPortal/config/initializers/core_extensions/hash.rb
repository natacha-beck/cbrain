
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

###################################################################
# CBRAIN Hash extensions
###################################################################
class Hash

  # This method allows you to perform a transformation
  # on all the keys of the hash; the keys are going to be passed
  # in turn to the block, and whatever the block returns
  # will be the new key. Example:
  #
  #   { "1" => "a", "2" => "b" }.convert_keys!(&:to_i)
  #
  #   returns
  #
  #   { 1 => "a", 2 => "b" }
  def convert_keys!
    self.keys.each do |key|
      self[yield(key)] = delete(key)
    end
    self
  end

  # Turns a hash table into a string suitable to be used
  # as HTML element attributes.
  #
  #   { "colspan" => 3, :style => "color: #ffffff", :x => '<>' }.to_html_attributes
  #
  # will return the string
  #
  #   'colspan="3" style="color: blue" x="&lt;&gt;"'
  def to_html_attributes
    self.inject("") do |result,attpair|
      attname   = attpair[0]
      attvalue  = attpair[1]
      result   += " " if result.present?
      result   += "#{attname}=\"#{ERB::Util.html_escape(attvalue)}\""
      result
    end
  end

end
