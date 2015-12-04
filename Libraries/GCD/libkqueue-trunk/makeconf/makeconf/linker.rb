# A linker combines multiple object files into a single executable or library file. 
#
class Linker

  attr_accessor :output, :objects, :quiet, :shared_library, :rpath, :platform_ldflags, :soname

  attr_reader :path, :ldadd

  def initialize
    @flags = []
    @user_flags = []
    @objects = []
    @output = 'a.out'
    @shared_library = false
    @ldadd = []
    @quiet = false          # If true, output will be suppressed
    @gcc_flags = true       # If true, options will be wraped in '-Wl,'
    @platform_ldflags = []    # Similar to cc.platform_flags
    @rpath = nil            # Optional -rpath setting
    @soname = nil           # Optional -soname value

    # Determine the path to the linker executable
    @path = nil
#TODO: support using Clang/GCC on windows
#if vendor == 'Microsoft'
    if Platform.is_windows?
      @path = 'LINK.EXE'
    else
      @path = 'ld' #XXX-FIXME horrible
    end

    if ENV['CC']
      @path = ENV['CC']
    end
    if ENV['LD']
      @path = ENV['LD']
    end
    self.path = @path       # KLUDGE
  end

  # Add all symbols to the dynamic symbol table (GNU ld only)
  def export_dynamic
    unless Platform.is_windows?
     @flags.push 'export-dynamic'
    end
  end

  # Set the full path to the linker executable
  def path=(p)
    @path = p
# FIXME: workaround for problem searching for clang 
#    if `#{@path} --version` =~ /GNU ld/
#      @gcc_flags = false
#    end
    #TODO: support other linkers
  end

  # Returns the linker flags suitable for passing to the compiler
  def flags
     input = @flags.clone
     tok = []

    # Set the output path
    throw 'Output pathname is required' if @output.nil?
    if Platform.is_windows?
      tok.push "/OUT:\"#{@output}\""
      tok.push '/DLL' if @output =~ /\.dll/i
    else
      tok.push '-o', @output
    end

    # Enable shared library output
    if @shared_library
      if Platform.is_windows?
        tok.push '/DLL'
      else
        tok.push '-shared'
        tok.push '-fPIC'
        input.push ['-soname', @soname] unless @soname.nil?
      end
    end

    # Assume that we want to link with shared libraries
    # built within this project
    unless Platform.is_windows?
      tok.push '-L', '.'
    end

    # Override the normal search path for the dynamic linker
    unless @rpath.nil?
      if Platform.is_solaris?
        input.push ['-R', @rpath]
      elsif Platform.is_linux?
        input.push ['-rpath', @rpath]
      elsif Platform.is_windows?
        # XXX-FIXME Windows does not support the rpath concept
      else
        throw 'Unsupported OS'
      end
      input.push ['-L', @rpath]
    end

    input.each do |f|
      if @gcc_flags == true
        if f.kind_of?(Array)
          if f[0] == '-L' or f[0] == '-R'
            tok.push f.join(' ')
          else
            tok.push '-Wl,' + f[0] + ',' + f[1]
          end
        else
          tok.push '-Wl,' + f
        end
      else
        if f.kind_of?(Array)
          tok.push f.flatten.join(' ')
        else
          tok.push f
        end
      end
    end

    res = ' ' + tok.join(' ')
    return res
  end

  def command
    # windows: 'link.exe /DLL /OUT:$@ ' + deps.join(' '))
    # linux: 'cc ' .... (see Compiler::)
    cmd = [ @path, @platform_ldflags, flags, @objects, sorted_ldadd ].flatten.join(' ')
    cmd += Platform.dev_null if @quiet and ENV['MAKECONF_DEBUG'].nil?
    log.debug "Linker command = `#{cmd}'"

    return cmd
  end

  # Return the command formatted as a Makefile rule
  def rule
     ['$(LD)', flags, '$(LDFLAGS)', @objects, sorted_ldadd, '$(LDADD)'].flatten.join(' ')
  end

  # Execute the linker command
  def link
    throw 'STUB'
  end

  def flags=(tok)
    @flags = default_flags
    return if tok.nil?
    if tok.kind_of?(Array)
      @flags.concat tok
    elsif tok.kind_of?(String)
      @flags.concat tok.split(' ') #XXX-broken, will not handle things like '-rpath /foo'
    else
      log.error tok.pretty_inspect
      throw 'Invalid flag type'
    end
  end

  # Try to determine a usable default set of linker flags
  def default_flags
    ldflags = []
    ldflags
  end

  # Set ldadd directly
  # See also: library()
  def ldadd=(x)
    x = x.split ' ' if x.kind_of? String
    @ldadd = x
  end

  # Add one or more libraries to the list of files to link
  def library(lib)
    case lib.class.to_s
    when 'Array'
      tok = lib
    when 'String'
      tok = lib.split(' ')
    else
      throw "Invalid value: #{lib.class}"
    end
    tok.each { |lib| @ldadd.push(lib) unless @ldadd.include?(lib) }
  end

private

  # Ensure that static archives are listed before dynamic libraries
  # so that unresolved symbols in the static archives can be provided
  # by a dynamic library
  #
  def sorted_ldadd
    res = []
    @ldadd.each do |ent|
      # KLUDGE: Android does not have a separate pthread.so
      if SystemType.host =~ /-androideabi$/
        next if ent =~ /^-lpthread$/
      end
      if ent =~ /\.a$/
        res.unshift ent
      else
        res.push ent
      end
    end
    res
  end

  def log
    Makeconf.logger
  end

end

