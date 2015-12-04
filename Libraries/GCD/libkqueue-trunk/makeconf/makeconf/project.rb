# A project contains all of the information about the build.
#
class Project
 
  require 'makeconf/systemtype'
  require 'makeconf/baseproject'

  # When each project is created, it is added to this list
  @@projects = []

  def self.new(options)
    if SystemType.host =~ /-androideabi$/
       require 'makeconf/androidproject'
       object = AndroidProject.allocate
    else
       object = BaseProject.allocate
    end
    @@projects.push object
    object.send :initialize, options
    object
  end

  def Project.all_projects
    @@projects
  end
end
