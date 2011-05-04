
# Helper methods for tasks views.

module TasksHelper

  Revision_info="$Id$"

  # Shows a bent-arrow character indented by +level+ 'spaces'
  # (actually, four NBSPs per level)
  def task_tree_view_icon(level)
    ('&nbsp' * 4 * level) + '&#x21b3;'
  end

  StatesToColor = {
          'Duplicated'                       => "blue",
          'Standby'                          => "orange",
          'Configured'                       => "orange",
          'New'                              => "blue",
          'Setting Up'                       => "blue",
          'Queued'                           => "blue",
          'On Hold'                          => "orange",
          'On CPU'                           => "blue",
          'Suspended'                        => "orange",
          'Data Ready'                       => "blue",
          'Post Processing'                  => "blue",
          'Completed'                        => "green",
          'Terminated'                       => "red",
          'Failed To Setup'                  => "red",
          'Failed To PostProcess'            => "red",
          'Failed On Cluster'                => "red",
          'Failed Setup Prerequisites'       => "red",
          'Failed PostProcess Prerequisites' => "red",
          'Recover Setup'                    => "purple",
          'Recover Cluster'                  => "purple",
          'Recover PostProcess'              => "purple",
          'Recovering Setup'                 => "purple",
          'Recovering Cluster'               => "purple",
          'Recovering PostProcess'           => "purple",
          'Restart Setup'                    => "blue",
          'Restart Cluster'                  => "blue",
          'Restart PostProcess'              => "blue",
          'Restarting Setup'                 => "blue",
          'Restarting Cluster'               => "blue",
          'Restarting PostProcess'           => "blue",
          'Preset'                           => "black",  # never seen in interface
          'SitePreset'                       => "black",  # never seen in interface
          'Failed'                           => "red"     # not an official task status, but used in reports
  }


  # Returns a HTML SPAN within which the text of the task +status+ is highlighted in color.
  def colored_status(status)
    return status unless StatesToColor.has_key?(status)
    html_colorize(status,StatesToColor[status])
  end

end
