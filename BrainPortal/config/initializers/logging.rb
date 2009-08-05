
#
# CBRAIN Project
#
# CBRAIN extensions for logging information about ANY
# object in the DB, as long as they have an 'id' field.
# Note that if the object being logged is an ActiveRecord,
# then the callback after_destroy() will clean up the
# logger object too. See the module ActRecLog for more
# information.
#
# Original author: Pierre Rioux
#
# $Id$
#

# 
# = CBRAIN Data Tracking API
# 
# It's important operations performed by CBRAIN users be tracked
# carefully. Whenever a data file is processed trough a scientific tool, we
# need to record somewhere that this was performed, and the record should
# contain not only the name of the tool but also its revision number,
# the revision numbers of other modules involved, and if possible what
# parameters were used. The same information should be recorded for the
# output files produced by the tools, too.
# 
# === The 'active_record_log' Table
# 
# As of subversion revision 393 of CBRAIN, a new database table will
# provide the data tracking facility. Although it is a normal Rails
# ActiveRecord table, it is designed to store objects related to ANY other
# ActiveRecords on the system, without using the Rails linking mechanism
# (those that are defined with 'belongs_to', 'has_many', 'has_one' etc).
# This table and its records are NOT expected to be ever accessed by CBRAIN
# programmers directly, instead a simple API has been added to the lowest
# level of the ActiveRecord class hierarchy, ActiveRecord::Base.
# 
# === The new ActiveRecord methods
# 
# There are four instance methods in the data tracking API. These
# four methods are available for ANY ActiveRecord object 'obj' on the
# system. They are:
# 
#     obj.addlog(message)
#     obj.addlog_context(ctx,message=nil)
#     obj.addlog_revinfo(data,message=nil)
#     obj.getlog()
# 
# All of these manipulate a simple text file that is associated precisely
# and uniquely with the object on which the method is called. The text
# file is stored as a single long string with embedded newlines.
# Here
# is how each of these method work, and in what situation you should use
# them.
# 
# * obj.addlog(message)
# 
# This is the simplest logging method. It simply appends the message
# string to the obj's current log. If the message is the very first
# message created for that object, then addlog will automatically
# prepend a line logging the class and revision information for
# the object 'obj'. The format of the appended line is:
# 
#   [2009-08-03 17:32:19] message
# 
# * obj.addlog_context(ctx,message=nil)
# 
# This method works like addlog(), but also prepends the optional
# message with callback information and revision information
# associated with 'ctx'. This method is meant to add a log
# entry describing where the program IS at the current moment,
# so usually and almost systematically, you should use 'self'
# as the ctx argument. The logged line will look like this:
# 
#   [2009-08-03 17:32:19] ctxclass currentmethod() ctxrevinfo message
# 
# * obj.addlog_revinfo(data,message=nil)
# 
# This message works like addlog(), but also prepends the optional
# message with revision information about the 'data', which can be
# almost anything (an object, or a class, or anything that responds
# to the CBRAIN 'revision_info' method). This method is meant to
# add a log entry describing information about another resource (the
# 'data') that is currently being used for processing this object.
# The logged line will look like this:
# 
#   [2009-08-03 17:32:19] dataclass datarevinfo message
# 
# * obj.getlog()
#
# Returns the current log as a single long string with embedded
# newlines. Will return nil if no log yet exists for the object.
#
# Note that along with these new methods, some ActiveRecord callbacks have
# been defined behind the scene such that any ActiveRecord object being
# destroy()ed will trigger the destruction of its associated log.
# 
# === Examples
# 
# Here's a complete example that show in which situations all three addlog()
# methods should be called, and what the resulting logs will look like.
# 
# Let's suppose we have a subroutine do_analysis() that receives a userfile
# 'myfile', does some processing on it using the methods 'shred' of the
# data processing object 'myshred' (of class 'Shredder'), which returns a
# new userfile 'resultfile'. The plain pseudo code looks like this (the
# content of two ruby files 'worker.rb' and 'shredder.rb' are shown):
# 
#   class Worker
#     Revision_info="SId: worker.rb 123 2009-07-30 16:55:47Z prioux S"
#     def do_analysis(myfile,myshred)
#       resultfile = myshred.shred(myfile)
#       return resultfile
#     end
#   end
# 
#   class Shredder
#     Revision_info="SId: shredder.rb 124 2009-08-30 13:25:12Z prioux S"
#     def shred(file)
#       resfile = Dosome.thing(file)
#       return resfile
#     end
#   end
# 
# We want to improve the code to record the information about all these steps
# and methods. Let's just sprinkle addlog() calls here and there:
# 
#   class Worker
#     Revision_info="SId: worker.rb 123 2009-07-30 16:55:47Z prioux S"
#     def do_analysis(myfile,myshred)
#       myfile.addlog_context(self,"Sending to Shredder")     #1
#       resultfile = myshred.shred(myfile)
#       myfile.addlog_context(self,"Created by Shredder")     #2
#       return resultfile
#     end
#   end
# 
#   class Shredder
#     Revision_info="SId: shredder.rb 124 2009-08-30 13:25:12Z prioux S"
#     def shred(file)
#       file.addlog_context(self)                             #3
#       file.addlog_revinfo(Dosome)                           #4
#       file.addlog("Processed by method 'thing')             #5
#       resfile = Dosome.thing(file)
#       resfile.addlog_context(self)                          #6
#       return resfile
#     end
#   end
# 
# The resulting logfiles associated with 'myfile' and 'resultfile'
# now contain a great deal of information about what happened to them.
# Here's the log for 'myfile'; the hashed numbers before the date stamp
# indicate which line of code created which log entry.
# 
#   #1 [2009-08-03 17:32:19] SingleFile revision 322 tsherif 2009-07-13
#   #1 [2009-08-03 17:32:19] Worker do_analysis() revision 123 prioux 2009-07-30 Sending to Shredder
#   #3 [2009-08-03 17:32:19] Shredder shred() revision 124 prioux 2009-08-30
#   #4 [2009-08-03 17:32:19] Dosome revision 66 prioux 2009-04-21
#   #5 [2009-08-03 17:32:19] Processed by method 'thing'
# 
# And here's the log for 'resultfile'.
# 
#   #6 [2009-08-03 17:32:19] SingleFile revision 322 tsherif 2009-07-13
#   #6 [2009-08-03 17:32:19] Shredder shred() revision 124 prioux 2009-08-30
#   #2 [2009-08-03 17:32:19] Worker do_analysis() revision 123 prioux 2009-07-30 Created by Shredder
# 
module ActRecLog

  Revision_info = "$Id$"

  # Add a log +message+ to the CBRAIN logging system
  # The first time a message is created, some revision
  # information about the current ActiveRecord class
  # will be added to the top of the log.
  def addlog(message)
    return true if self.is_a?(ActiveRecordLog)
    begin
      arl = active_record_log_find_or_create
      return false unless arl
      log = arl.log
      log = "" if log.blank?
      lines = message.split(/\s*\n/)
      lines.pop while lines.size > 0 && lines[-1] == ""
  
      message = lines.join("\n") + "\n"
      log += Time.now.strftime("[%Y-%m-%d %H:%M:%S] ") + message
      arl.update_attributes( { :log => log } )
    rescue
      false
    end
  end

  # Creates a custom log entry with info about the context
  # where this method is called; the +context+ argument
  # can be any object or class, and its revision_info
  # will be extracted for the final message. Optionally,
  # you can add some more text to the end of the log entry.
  #
  # Using this method on an ActiveRecord
  # +obj+ from the method xyz() of class +Abcd+,
  # like this:
  #
  #     obj.addlog_context(self,"hello")
  #
  # results is a log entry like this one:
  #
  #     "Abcd xyz() revision 123 prioux 2009-05-23 hello"
  def addlog_context(context,message=nil)
    return true if self.is_a?(ActiveRecordLog)
    prev_level     = caller[0]
    calling_method = prev_level.match(/in `(.*)'/) ? ($1 + "()") : "unknown()"

    class_name     = context.class.to_s
    class_name     = context.to_s if class_name == "Class"
    rev_info       = context.revision_info
    pretty_info    = rev_info.svn_id_pretty_rev_author_date
 
    full_message   = "#{class_name} #{calling_method} revision #{pretty_info}"
    full_message   += " #{message}" unless message.blank?
    self.addlog(full_message)
  end

  # Creates a custom log entry with the revision info
  # about +anobject+, which is any object or class, supplied as
  # the first argument. Its revision_info will be extracted for
  # the final message. Optionally, you can add some
  # more text to the end of the log entry.
  #
  # Using this method on an ActiveRecord
  # +obj+ with the class +Abcd+ in argument,
  # like this:
  #
  #     obj.addlog_revinfo(Abcd,"hello")
  #
  # results is a log entry like this one:
  #
  #     "Abcd revision 123 prioux 2009-05-23 hello"
  def addlog_revinfo(anobject,message=nil)
    return true if self.is_a?(ActiveRecordLog)
    class_name     = anobject.class.to_s
    class_name     = anobject.to_s if class_name == "Class"
    rev_info       = anobject.revision_info
    pretty_info    = rev_info.svn_id_pretty_rev_author_date
 
    full_message   = "#{class_name} revision #{pretty_info}"
    full_message   += " #{message}" unless message.blank?
    self.addlog(full_message)
  end

  # Gets the log for the current ActiveRecord;
  # this is a single long string with embedded newlines.
  def getlog
    return nil if self.is_a?(ActiveRecordLog)
    arl = active_record_log
    return nil unless arl
    arl.log
  end

  protected

  def active_record_log #:nodoc:
    return nil if self.is_a?(ActiveRecordLog)
    myid    = self.id
    myclass = self.class.to_s
    return nil unless myid
    ActiveRecordLog.find(
       :first,
       :conditions => { :ar_id => myid, :ar_class => myclass }
    )
  end

  def active_record_log_find_or_create #:nodoc:
    return nil if self.is_a?(ActiveRecordLog)
    arl = active_record_log
    return arl if arl
    
    myid    = self.id
    myclass = self.class.to_s
    return nil unless myid
    message = Time.now.strftime("[%Y-%m-%d %H:%M:%S] ") + "#{myclass} revision " +
              self.revision_info.svn_id_pretty_rev_author_date + "\n"

    arl = ActiveRecordLog.create( :ar_id    => myid,
                                  :ar_class => myclass,
                                  :log      => message )
    arl
  end

end

class ActiveRecord::Base
  include ActRecLog

  after_destroy :destroy_log

  # Destroy the log associated with an ActiveRecord.
  # This is usually called automatically as a +after_destroy+
  # callback when the record is destroyed, but it can be
  # called manually too.
  def destroy_log
    return true if self.is_a?(ActiveRecordLog)
    arl = self.active_record_log
    return true unless arl
    arl.destroy_without_callbacks
    true
  end
end

class ActiveResource::Base
  include ActRecLog
end
