
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

# Module to save stdout and stderr files
module BoutiquesSaveStdOutStdErr

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method overrides the one in BoutiquesClusterTask
  def save_results
    # Performs standard processing
    return false unless super
    self.addlog("Saving results...")

    # Get the folder where to save the log files from the descriptor
    descriptor      = self.descriptor_for_save_results
    save_log_folder = descriptor.custom_module_info('BoutiquesSaveStdOutStdErr')

    # Save stdout and stderr
    parent_file   = Userfile.find((self.params[:invoke] ||= {})[descriptor.file_inputs.first.id])

    # save stdout
    hidden_science_stdout_basename = science_stdout_basename(self.run_number)
    science_stdout_basename        = hidden_science_stdout_basename.gsub(/^\.science./, "")
    copy_to_location               = save_log_folder["stdout_output_dir"] == true ?
                                        science_stdout_basename :
                                        (save_log_folder["stdout_output_dir"] || "") + science_stdout_basename

    return false if !save_log_file(hidden_science_stdout_basename, copy_to_location, parent_file)

    # save stderr
    hidden_science_stderr_basename = science_stderr_basename(self.run_number)
    science_stderr_basename        = hidden_science_stderr_basename.gsub(/^\.science./, "")
    copy_to_location               = save_log_folder["stderr_output_dir"] == true ?
                                        science_stderr_basename :
                                        (save_log_folder["stderr_output_dir"] || "") + science_stderr_basename

    return false if !save_log_file(hidden_science_stderr_basename, copy_to_location, parent_file)

    true
  end

  def descriptor_for_show_params  #:nodoc:
    descriptor = descriptor_for_form

    stdout_file = BoutiquesSupport::OutputFile.new({
      "id"   => "stdout",
      "name" => "stdout",
      "description" => "Standard output of the tool",
      "optional" => true
    })

    stderr_file = BoutiquesSupport::OutputFile.new({
      "id" => "stderr",
      "name" => "stderr",
      "description" => "Standard error of the tool",
      "optional" => true
    })

    descriptor["output-files"] << stdout_file if !descriptor["output-files"].find { |f| f["id"] == "stdout" }
    descriptor["output-files"] << stderr_file if !descriptor["output-files"].find { |f| f["id"] == "stderr" }

    descriptor
  end

  # This method overrides the method in BoutiquesClusterTask.
  # If the name for the file contains a relative path such
  # as "a/b/c/hello.txt", it will extract the "a/b/c" and
  # provide it in the browse_path attribute to the Userfile
  # constructor in super().
  def safe_userfile_find_or_new(klass, attlist)
    name = attlist[:name]
    return super(klass, attlist) if ! (name.include? "/") # if there is no relative path, just do normal stuff

    # Find all the info we need
    attlist = attlist.dup
    dp_id   = attlist[:data_provider_id] || self.results_data_provider_id
    dp      = DataProvider.find(dp_id)
    pn      = Pathname.new(name)  # "a/b/c/hello.txt"

    # Make adjustements to name and browse_path
    attlist[:name] = pn.basename.to_s  # "hello.txt"
    if dp.has_browse_path_capabilities?
      attlist[:browse_path] = pn.dirname.to_s   # "a/b/c"
      self.addlog "BoutiquesSaveStdErrOut: result DataProvider browse_path for Stderr and Stdout will be '#{pn.dirname}'"
    else
      attlist[:browse_path] = nil # ignore the browse_path
      self.addlog "BoutiquesSaveStdErrOut: result DataProvider doesn't have multi-level capabilities, ignoring forced browse_path for Stderr and Stdout '#{pn.dirname}'."
    end

    # Invoke the standard code
    return super(klass, attlist)
  end

  private

  def save_log_file(original_filename, copy_to_location, parent_file)
    file = safe_userfile_find_or_new(LogFile,
      :name             => copy_to_location,
      :data_provider_id => self.results_data_provider_id
    )

    file.cache_copy_from_local_file(original_filename)
    if file.save
      file.move_to_child_of(parent_file)
      self.addlog("Saved output file #{original_filename}")
      self.params["_cbrain_output_stdout"] = file.id if original_filename == science_stdout_basename(self.run_number)
      self.params["_cbrain_output_stderr"] = file.id if original_filename == science_stderr_basename(self.run_number)
    else
      self.addlog("Could not save back result file #{original_filename}")
      return false
    end

    self.save

    true
  end
end

