
/*
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
*/

(function() {
  "use strict";

  document.addEventListener("DOMContentLoaded", function(event) {

    document.getElementById("upload_file").addEventListener('input', function (event) {
      var warning_text = "";
      var max          = parseInt(document.getElementById('upload-info').dataset["maxUploadSize"]);
      var select_file  = document.getElementById("upload_file").files[0]
      var filename     = select_file && select_file.name;
      var filesize     = select_file && select_file.size;
      var bad_file;

      var allowed_file_pattern = /^[a-zA-Z0-9][\w\~\!\@\#\%\^\&\*\(\)\-\+\=\:\[\]\{\}\|\<\>\,\.\?]*$/;
      var bad_chars = !allowed_file_pattern.test(filename);

      var spaces_in_name = filename.includes(" ");
            
      var file_too_big;
      if ( max > 0 ){
        file_too_big = filesize && max && filesize > max;
      } else {
        file_too_big = false;
      }

      bad_file = ( bad_chars || file_too_big || spaces_in_name );

      if ( bad_chars && spaces_in_name) {
        warning_text += "No spaces allowed in filename! ";
      }
      else if ( bad_chars ) {
        warning_text += "Illegal filename: must start with letter/digit, and no slashes, or ASCII nulls allowed. ";
      }
      if ( file_too_big ) {
        warning_text += "Too large! (> " + max/1048576 + " MB) ";
      }

      document.getElementById("up-file-warn").textContent      = warning_text;
      document.getElementById("up-file-warn").style.visibility = bad_file ? 'visible' : 'hidden';

    }, false);


    document.getElementById("upload").addEventListener('submit', function (event) {
      document.getElementById('div_loader').style.display = "block";
      document.getElementById('upload_file_btn').disabled = true;
    }, false);
  }, false);

})();
