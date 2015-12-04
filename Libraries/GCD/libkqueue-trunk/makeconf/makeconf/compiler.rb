# Processes source code files to produce intermediate object files.
#
class Compiler

  require 'tempfile'

  attr_accessor :sysroot, :output, :platform_cflags, :ld
  attr_reader :vendor, :path

  def initialize(language, extension)
    @language = language
    @extension = extension
    @ld = Linker.new()
    windows_init if Platform.is_windows?
    @flags = []
    @sources = []     # List of input files
    @output = nil
    @platform_cflags = []   # Cflags required by the SystemType
    @sysroot = nil
    @quiet = false          # If true, output will be suppressed
    @vendor = 'Unknown'

    # TODO:
    # If true, all source files will be passed to the compiler at one time.
    # This will also combine the link and compilation phases.
    # See: the -combine option in GCC
    #@combine = false

  end

  def sources=(a)
    a = [ a ] if a.kind_of?(String)
    throw 'Array input required' unless a.kind_of?(Array)
    @sources = a
    @ld.objects = a.map { |x| x.sub(/\.c$/, Platform.object_extension) } #FIXME: hardcoded to C
  end

  def cflags
    @flags
  end

  # Return the intermediate object files for each source file
  def object_files(sources)
    res = []
    sources.sort.each do |s|
      res.push s.sub(/.c$/, Platform.object_extension)
    end
    res
  end

  def quiet=(b)
    ld.quiet = b
    @quiet = b
  end

  def makefile
    m = Makefile.new
    m.define_variable('CC', '=', @path)
    m.define_variable('LD', '=', @ld.path)
    return m
  end

  # Return the command formatted as a Makefile rule
  def rule
    [ '$(CC)', '-DHAVE_CONFIG_H', '-I.', flags, '$(CFLAGS)', '-c', @sources ].flatten.join(' ')
  end

  # Return the complete command line to compile an object
  def command
    log.debug self.pretty_inspect

    throw 'Invalid linker' unless @ld.is_a?(Linker)
    throw 'One or more source files are required' unless @sources.length > 0
#      cflags = default_flags
#      cflags.concat @flags
#    end
#    throw cflags

#    topdir = h[:topdir] || ''
#    ld = @ld
#    ldadd = h[:ldadd]
#    ld.flags = h[:ldflags]
#    ld.output = Platform.pathspec(h[:output])
#    ld.rpath = h[:rpath] if h[:rpath].length > 0

#    inputs = h[:sources]
#    inputs = [ inputs ] if inputs.is_a? String
#    inputs = inputs.map { |x| Platform.pathspec(topdir + x) }
#    throw 'One or more sources are required' unless inputs.count

#TODO:if @combine
# return [ @path, cflags, '-combine', ldflags, inputs, ldadd ].flatten.join(' ')
#
    
    cmd = [ @path, '-DHAVE_CONFIG_H', '-I.', @platform_cflags, flags, '-c', @sources ].flatten.join(' ')

    cmd += Platform.dev_null if @quiet

    log.debug "Compiler command: #{cmd}"

    cmd
  end


  def flags
    tok = @flags.clone

    # KLUDGE: remove things that CL.EXE doesn't understand
    if @vendor == 'Microsoft'
      tok = tok.flatten.map do |t|
        t.gsub!(/^-Wall$/, ' ') #  /Wall generates too much noise
        t.gsub!(/^-Werror$/, ' ')  # Could use /WX here
        t.gsub!(/^-W$/, ' ')
        t.gsub!(/^-Wno-.*?/, ' ')
        t.gsub!(/^-Wextra$/, ' ')
        t.gsub!(/^-fPIC$/, ' ')
        t.gsub!(/^-std=.*?$/, ' ')
        t.gsub!(/^-pedantic$/, ' ')
      end
    end

    # Set the output path
    unless @output.nil?
      outfile = Platform.pathspec(@output)
      if @vendor == 'Microsoft'
        tok.push '"-IC:\Program Files\Microsoft Visual Studio 10.0\VC\include"' # XXX-HARDCODED
        tok.push '/Fo' + outfile
        tok.push '/MD'
      else
        tok.push '-o', outfile
      end
    end

    if @ld.shared_library 
      if Platform.is_windows?
        throw 'FIXME'
      else
        tok.push('-fPIC', '-DPIC') unless is_mingw?
      end
    end

    tok.push '--sysroot=' + @sysroot unless @sysroot.nil?

    tok.join(' ')
  end

  def flags=(s)
    if s.kind_of?(String)
      @flags = s.split(' ') # FIXME: need to handle quoted strings w/ spaces
    elsif s.kind_of?(Array)
      @flags = s.clone
    else
      raise ArgumentError, "invalid flag type"
    end
  end

  # Enable compiler and linker options to create a shared library
  def shared_library=(b)
    case b
    when true
      if Platform.is_windows?
        # noop
      else
        @flags.push '-fpic'
        @ld.shared_library = true
      end
    when false
      # noop
    else
      throw 'Invalid value'
    end
  end

  # Test if the compiler supports a command line option
  def has_option(opt)

    # Create a simple test file
    f = Tempfile.new(['test_has_option', @extension]);
    f.puts 'int main() { }'
    f.flush

#FIXME: /dev/null not portable
    cmd = [ @path, opt, '-o /dev/null', '-c', f.path ].join(' ') + Platform.dev_null
    Platform.execute cmd
  end

  # Check if a header is available
  def check_header(path)
    test_compile("#include <" + path + ">")
  end

  # Compile and link a test program
  def test_link(code)
    test_compile(code, :combined)
  end

  # Run the compilation command
  def compile
    cmd = self.command
#puts ' + ' + cmd
    log.debug "Invoking the compiler"
    rc = Platform.execute cmd
    log.debug "Compilation complete; rc=#{rc.to_s}"
    rc
  end

  # Run the link command
  def link
    throw 'Invalid linker' unless @ld.is_a?(Linker)
    throw 'One or more source files are required' unless @sources.length > 0
    cmd = @ld.command
    log.debug "Invoking the linker: " + cmd
    rc = Platform.execute cmd
    log.debug "Linking complete; rc=#{rc.to_s}"
    rc
  end

  # Compile a test program
  def test_compile(code, stage = :compile)
    log.debug "Testing compilation of:\n" + code

    # Write the code to a temporary source file
    f = Tempfile.new(['test_compile', @extension]);
    f.print code
    f.flush

    # Run the compiler
    cc = self  # KLUDGE, testing
    cc.sources = f.path
    cc.output = f.path.sub(/\.c$/, Platform.object_extension)
    cc.quiet = ENV['MAKECONF_DEBUG'].nil?
    rc = cc.compile

    # (Optional) Run the linker
    if (rc == true and stage == :combined)
      cc.ld.quiet = true
      rc = cc.link
      File.unlink(cc.ld.output) if File.exist? cc.ld.output
    end

    # Delete the output file(s)
    File.unlink(cc.output) if File.exist? cc.output

    return rc
  end

 
  # Try to determine a usable default set of compiler flags
  def default_flags
    cflags = []

    # GCC on Solaris 10 produces 32-bit code by default, so add -m64
    # when running in 64-bit mode.
    if Platform.is_solaris? and Platform.word_size == 64
       cflags.push '-m64'
    end

    cflags
  end

  # Return the list of dependencies to pass to make(1)
  def makedepends(source_file)
    res = []

    if @vendor == 'GNU'
      flags = @flags.join ' '
      cmd = "#{@path} -I. #{includedirs()} #{flags} -MM #{source_file}"
      #warn "Generating dependencies for #{source_file}..\n + #{cmd}" 
      tmp = `#{cmd}`
      return [] if tmp.nil?
      tmp.sub!(/^.*\.o: /, '')
      return [] if tmp.nil?
      tmp.gsub!(/\\\n/, ' ')
      res = tmp.split(/\s+/)
    else
      throw 'Not supported -- need to use a fallback method'
    end

    res.push 'GNUmakefile'
    res
  end

  private

  # Return a string containing the include directories from
  # CFLAGS (e.g. "-I. -Iinclude -Iblah"
  def includedirs
    res = []
    @flags.each { |f| res.push f if f =~ /^-I/ }
    res.join " "
  end

  # Special initialization for MS Windows
  def windows_init
    # FIXME: hardcoded to VS10 on C: drive, should pull the information from vcvars.bat
    ENV['PATH'] = 'C:\Program Files\Microsoft Visual Studio 10.0\Common7\IDE\;C:\Program Files\Microsoft Visual Studio 10.0\VC\BIN;C:\Program Files\Microsoft Visual Studio 10.0\Common7\Tools' + ENV['PATH']
    ENV['INCLUDE'] = 'INCLUDE=C:\Program Files\Microsoft Visual Studio 10.0\VC\INCLUDE;C:\Program Files\Microsoft SDKs\Windows\v7.0A\include;'
    ENV['LIB'] = 'C:\Program Files\Microsoft Visual Studio 10.0\VC\LIB;C:\Program Files\Microsoft SDKs\Windows\v7.0A\lib;'
    ENV['LIBPATH'] = 'C:\WINDOWS\Microsoft.NET\Framework\v4.0.30319;C:\WINDOWS\Microsoft.NET\Framework\v3.5;C:\Program Files\Microsoft Visual Studio 10.0\VC\LIB;'
    ENV['VCINSTALLDIR'] = "C:\Program Files\\Microsoft Visual Studio 10.0\\VC\\"
    ENV['VS100COMNTOOLS'] = "C:\\Program Files\\Microsoft Visual Studio 10.0\\Common7\\Tools\\"
    ENV['VSINSTALLDIR'] = "C:\\Program Files\\Microsoft Visual Studio 10.0\\"
    ENV['WindowsSdkDir'] = "C:\\Program Files\\Microsoft SDKs\\Windows\\v7.0A\\"
  end

  # Search for a suitable compiler
  def search(compilers)
    res = nil
    if ENV['CC']
      res = ENV['CC']
    else
      compilers.each do |command|
         if (command =~ /^\// and File.exists?(command)) or Platform.which(command)
           res = command
           break
         end
      end
    end

    # FIXME: kludge for Windows, breaks mingw
    if Platform.is_windows?
        res = 'cl.exe'
    end

    throw 'No suitable compiler found' if res.nil? || res == ''

    if Platform.is_windows? && res.match(/cl.exe/i)
        help = ' /? <NUL'
    else
        help = ' --help'
    end
    
    # Verify the command can be executed
    cmd = res + help + Platform.dev_null
    unless Platform.execute(cmd)
       puts "not found"
       print " -- tried: " + cmd
       raise
    end

    puts res
    res
  end

  # Set the full path to the compiler executable
  def path=(p)
    @path = p
    @ld.path = p        # FIXME: not always true

    # Try to detect the vendor
    if Platform.is_windows? and @path.match(/cl.exe$/i)
      @vendor = 'Microsoft'
    elsif `#{@path} --version` =~ /Free Software Foundation/
      @vendor = 'GNU'
    elsif `#{@path} --version` =~ /clang|llvm/i
      @vendor = 'GNU'   # WORKAROUND -- flags are generally compatible
    else
      @vendor = 'Unknown'
    end
  end

end

class CCompiler < Compiler

  attr_accessor :output_type
  attr_reader :path

  def initialize(options = {})
    @search_list = options.has_key?(:search) ? options[:search] : [ 'cc', 'gcc', 'clang', 'cl.exe']
    @search_list = [ @search_list ] unless @search_list.kind_of?(Array)
    @output_type = nil
    super('C', '.c')
    printf "checking for a C compiler.. "
    self.path = search(@search_list)
  end

  # Returns true if the compiler is MinGW
  def is_mingw?
    @path =~ /mingw/        # Kludge
  end

private

  def log
    Makeconf.logger
  end

end
