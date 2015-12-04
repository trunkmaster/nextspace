# The archiver creates a static library from one or more object files
#
class Archiver

  attr_accessor :output, :objects
  attr_reader :path, :ranlib

  def initialize(output = nil, objects = [])
    @flags = 'cru'      # GNU-specific; more portable is 'rcs'
    @output = output
    @objects = objects
    @path = nil

    if ENV['LD']
      self.path = ENV['LD']
    else
      self.path = 'ar'
    end

    if ENV['RANLIB']
      @ranlib = ENV['RANLIB']
    else
      @ranlib = 'ranlib'
    end
  end

  # Set the full path to the archiver executable
  def path=(p)
    @path = p
    # TODO: Support non-GNU archivers
    #if `#{@path} --version` =~ /^GNU ar/
#  @gcc_flags = false
#    end
  end

  def makefile
    m = Makefile.new
    m.define_variable('AR', '=', @path)
    m.define_variable('RANLIB', '=', @ranlib)
    return m
  end

  def command
    cmd = [ '$(AR)', @flags, @output, @objects].flatten.join(' ')
    log.debug "Archiver command = `#{cmd}'"
    cmd
  end

  # Return the command formatted as a Makefile rule
  def to_make
    Target.new(@output, @objects, [
            Target::ConditionalRule.new([command, "$(RANLIB) #{output}"]).ifneq('$(DISABLE_STATIC)','1')
            ])
  end

private

  def log
    Makeconf.logger
  end

end
