# A project contains all of the information about the build.
# This is the base class from which all other Project subclasses are built
#
class BaseProject
 
  require 'net/http'
  require 'yaml'

  attr_accessor :id, :version, :summary, :description, 
        :author, :license, :license_file, :config_h,
        :custom_configure_script

  attr_reader :cc, :ar

  attr_accessor :makefile, :installer, :packager

  def log
    Makeconf.logger
  end

  # Called by the object constructor
  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    @id = 'myproject'
    @version = '0.1'
    @summary = 'Undefined project summary'
    @description = 'Undefined project description'
    @license = 'Unknown license'
    @license_file = nil
    @author = 'Unknown author'
    @config_h = 'config.h'
    @custom_configure_script = false # If true, ./configure will not be generated
    @config_h_rules = [] # Makefile rules to generate config.h
    @header = {}        # Hash of system header availablity
    @build = []         # List of items to build
    @distribute = []    # List of items to distribute
    @target = []        # List of additional Makefile targets
    @decls = {}         # List of declarations discovered via check_decl()
    @decls_rules = []   # Makefile rules based on @decls
    @funcs = {}         # List of functions discovered via check_func()
    @defs = {}          # Custom preprocessor macro definitions
    @condvars = []      # Conditional Makefile variables
    @packager = Packager.new(self)
    @ar = Archiver.new
    @cc = nil

    # Provided by the parent Makeconf object
    @installer = nil
    @makefile = nil

#    # Initialize missing variables to be empty Arrays 
#    [:manpages, :headers, :libraries, :tests, :check_decls, :check_funcs,
#     :extra_dist, :targets, :binaries].each do |k|
#       h[k] = [] unless h.has_key? k
#       h[k] = [ h[k] ] if h[k].kind_of?(String)
#    end
#    h[:scripts] = {} unless h.has_key?(:scripts)

     # Generate a hash containing all the different element types
     #items = {}
     #%w{manpage header library binary test check_decl check_func extra_dist targets}.each do |k|
     #  items[k] = xml.elements[k] || []
     #end

     options.each do |key,val|
        #p "key=#{key} val=#{val}"
       case key
       when :id
         @id = val
       when :version
         @version = val.to_s
       when :cc
         @cc = val
       when :config_h
         @config_h = val
       when :license_file
         @license_file = val
       when 'library', 'libraries'
         val.each do |id, e|
           build SharedLibrary.new(id, @cc).parse(e)
           build StaticLibrary.new(id, @cc).parse(e)
         end
       when 'manpage'
          manpage(val)  
       when 'header'
          header(val)  
       when 'extra_dist'
          distribute val 
       when 'targets'
          target val
       when 'script', 'check_decl', 'check_func'
          throw 'FIXME'
            #items['script'].each { |k,v| script(k,v) }
            #items['check_decl'].each { |id,decl| check_decl(id,decl) }
#items['check_func'].each { |f| check_func(f) }
       else
          throw "Unknown option -- #{key}: #{val}"
       end
     end

    # Determine the path to the license file
    if @license_file.nil?
      %w{COPYING LICENSE}.each do |p|
        if File.exists?(p)
            @license_file = p
            break
        end
      end
    end

    @cc ||= CCompiler.new 


    yield self if block_given?
  end

  # Parse ARGV options
  # Should only be called from Makeconf.parse_options()
  def parse_options(opts)
    opts.separator ""
    opts.separator "Project options:"
#none yet
  end

  # Examine the operating environment and set configuration options
  def configure

    preconfigure if respond_to? 'preconfigure'

    # Run each buildable object's project_hook() method
    @build.each { |x| x.project_hook(self) }

    # Run each buildable object's preconfigure() method
    @build.each { |x| x.preconfigure if x.respond_to? 'preconfigure' }

    # Run each buildable object's configure() method
    @build.each { |x| x.configure if x.respond_to? 'configure' }

    postconfigure if respond_to? 'postconfigure'

    # Run each buildable object's postconfigure() method
    @build.each { |x| x.postconfigure if x.respond_to? 'postconfigure' }

    # Test for the existence of each referenced system header
#sysdeps.each do |header|
#      printf "checking for #{header}... "
#      @header[header] = @cc.check_header(header)
#      puts @header[header] ? 'yes' : 'no'
#    end

#    make_installable(@ast['data'], '$(PKGDATADIR)')
#    make_installable(@ast['manpages'], '$(MANDIR)') #FIXME: Needs a subdir
  end

  # Return the Makefile for the project
  # This should only be done after finalize() has been called.
  def to_make
    makefile = Makefile.new

    makefile.add_dependency('dist', distfile)
    makefile.add_dependency('distdir', @config_h)
    makefile.distclean(distfile)
    makefile.distclean(@config_h)
    makefile.distclean('config.yaml')
    makefile.merge!(@ar.makefile)
    makefile.merge!(@cc.makefile)
    makefile.merge!(@packager.makefile)
    makefile.make_dist(@id, @version)
    @condvars.each { |cv| makefile.define_conditional_variable(cv) }
    @distribute.each { |f| makefile.distribute f }
    @build.each do |x| 
       if x.buildable == true
         # KLUDGE: would like a reset() function to reset
         #         compiler/linker to default states
         @cc.shared_library = false
         @cc.ld.shared_library = false

         makefile.merge!(x.compile(@cc))
         makefile.merge!(x.link(@cc.ld))
         x.makefile_hook(makefile)
       end
    end
    makefile.merge! @installer.to_make

    # Add custom targets
    @target.each { |t| makefile.add_target t }

    # Add the config.h target
    @config_h_rules.unshift \
        '@echo "checking build system type... $(BUILD_TYPE)"',
        '@echo "checking host system type... $(HOST_TYPE)"',
        '@echo "/* AUTOMATICALLY GENERATED -- DO NOT EDIT */" > config.h.tmp',
        '@date > config.log'
    @config_h_rules.concat @decls_rules
    @header.keys.sort.each do |header|
      uc_var = 'HAVE_' + header.upcase.gsub(/\.|\//, '_')
      @config_h_rules.push "@printf \"checking for #{header}... \"",
        "@( echo '#include <#{header}>' | $(CC) $(CFLAGS) -E -x c - ) >/dev/null 2>&1 && " +
        "( echo '#define #{uc_var} 1' >> config.h.tmp ; echo 'yes' ) || (echo '/* #undef #{uc_var} */' >> config.h.tmp ; echo 'no' )"
    end
    @config_h_rules.push \
        '@rm -f conftest.c conftest.o',
        '@echo "creating config.h"',
        '@mv config.h.tmp ' + @config_h
    makefile.add_target Target.new(@config_h, [], @config_h_rules) 

    makefile.distribute ['configure', 'configure.rb', 'GNUmakefile']
    makefile.distribute @license_file unless @license_file.nil?

    makefile
  end

  def finalize
    @build.each do |x| 
      x.finalize 
      x.install @installer
    end
    @packager.finalize
  end

  # Check if a system header file is available
  def check_header(headers)
      headers = [ headers ] if headers.kind_of? String
      throw ArgumentError unless headers.kind_of? Array
      rc = true

      headers.each do |header|
        printf "checking for #{header}... "
        @header[header] = @cc.check_header(header)
        if @header[header]
          puts 'yes'
        else
          puts 'no'
          rc = false
        end
      end

      rc
  end

  # Check if a system header declares a macro or symbol
  def check_decl(decl, *opt)
      decl = [ decl ] if decl.kind_of? String
      opt = opt.nil? ? [ :include => 'stdlib.h' ] : opt[0]
      throw ArgumentError unless decl.kind_of? Array
      rc = true

      decl.each do |x|
        next if @decls.has_key? x
        printf "checking whether #{x} is declared... "
        source = [
         "#define _GNU_SOURCE",
         "#include <#{opt[:include]}>", #XXX-support multiple includes
         "int main() { #{x}; }"
         ]
        @decls[x] = @cc.test_compile(source.join("\n"))
        if @decls[x]
          puts 'yes'
        else
          puts 'no'
          rc = false
        end

      # KLUDGE: also doing it via the Makefile. We should stop doing the check during ./configure time
      uc_var = 'HAVE_DECL_' + x.upcase
      header_to_check = opt[:include] ? " in #{opt[:include]}" : ''
      @decls_rules.push "@printf \"checking whether #{x} is declared#{header_to_check}... \" | tee -a config.log",
"@( printf '#{source.join('\n')}' | $(CC) $(CFLAGS) -E -x c - ) >/dev/null 2>>config.log && " +
        "( echo '#define #{uc_var} 1' >> config.h.tmp ; echo 'yes' ) || (echo '#define #{uc_var} 0' >> config.h.tmp ; echo 'no' )"
      end

      rc
  end

  # Check if a function is available in the standard C library
  # TODO: probably should add :ldadd when checking..
  def check_function(func, arg = {})
      func = [ func ] if func.kind_of? String
      throw ArgumentError unless func.kind_of? Array
      rc = true

      # Save the previous state of variables
      old_ldadd = @cc.ld.ldadd

      # Temporarily override some variables
      @cc.ld.ldadd = arg[:ldadd] if arg.has_key?:ldadd

      func.each do |x|
        next if @funcs.has_key? x
        printf "checking for #{x}... "
        @funcs[x] = @cc.test_link "void *#{x}();\nint main() { void *p;\np = &#{x}; }"
        if @funcs[x] 
          puts 'yes'
        else
          puts 'no'
          rc = false
        end
      end

      # Restore the previous state of variables
      @cc.ld.ldadd = old_ldadd

      rc
  end

  # Define a C preprocessor symbol 
  def define(id,value = 1)
    @defs[id] = value
  end

  def add_binary(options)
    options[:cc] ||= @cc
    id = options[:id] + Platform.executable_extension
    build Binary.new(options)
  end

  def add(*objs)
    objs.each do |obj|
      if obj.kind_of?(Library)
        obj.buildable.each do |e|
           add(e)
        end
      elsif obj.kind_of?(Makefile::Conditional)
        @condvars.push(obj)
      else
        obj.project = self if obj.kind_of?(Buildable)
        build(obj)
      end
    end
  end

  # Add item(s) to build
  def build(*arg)
    arg.each do |x|

      # Add a custom Makefile target
      if x.kind_of? Target
          @target.push x
          next
      end

      unless x.respond_to?(:compile)
        throw ArgumentError.new('Invalid argument') 
      end

      @build.push x
    end
  end

  # Add item(s) to install
  def install(*arg)
    arg.each do |x|
      # FIXME: shouldn't something be installed now?
      @distribute.push Dir.glob(x)
    end
  end

  # Add item(s) to distribute in the source tarball
  def distribute(*arg)
    arg.each do |x|
      @distribute.push Dir.glob(x)
    end
  end

  # Add a C/C++ header file to be installed
  def header(path, opt = {})
    throw ArgumentError, 'bad options' unless opt.kind_of? Hash
    @install.push({ 
        :sources => path,
        :dest => (opt[:dest].nil? ? '$(INCLUDEDIR)' : opt[:dest]),
        :mode => '0644',
        })
  end

  # Add a manpage file to be installed
  def manpage(path, opt = {})
    throw ArgumentError, 'bad options' unless opt.kind_of? Hash
    section = path.gsub(/.*\./, '')
    @install.push({ 
        :sources => path,
        :dest => (opt[:dest].nil? ? "$(MANDIR)/man#{section}" : opt[:dest]),
        :mode => '0644',
        })
  end

  # Add a script to be installed
  def script(id, opt = {})
    throw ArgumentError, 'bad options' unless opt.kind_of? Hash
    @install.push({ 
        :sources => opt[:sources],
        :dest => (opt[:dest].nil? ? "$(BINDIR)" : opt[:dest]),
        :rename => opt[:rename],
        :mode => '0755',
        })
  end

  # Return the compiler associated with the project
  def compiler(language = 'C')
    throw 'Not implemented' if language != 'C'
    throw 'Undefined compiler' if @cc.nil?
    @cc
  end

  # Return a library definition
  def library(id)
    @ast['libraries'][id]
  end

  # Return a list of all system header dependencies for all Buildable
  # objects in the project.
  def sysdeps
    res = []
    @build.each do |x|
      x.sysdep.each { |k,v| res.concat v }
    end
    res.sort.uniq
  end

  # Returns the filename of the source code distribution archive
  def distfile
    @id + '-' + @version.to_s + '.tar.gz'
  end

  # Generate the config.h header file
  def write_config_h
    ofile = @config_h
    buf = {}

    @header.keys.sort.each { |k| buf["HAVE_#{k}".upcase] = @header[k] }
    @decls.keys.sort.each { |x| buf["HAVE_DECL_#{x}".upcase] = @decls[x] }
    @funcs.keys.sort.each { |x| buf["HAVE_#{x}".upcase] = @funcs[x] }

    puts 'creating ' + ofile
    f = File.open(ofile, 'w')
    f.print "/* AUTOMATICALLY GENERATED -- DO NOT EDIT */\n"
    buf.keys.sort.each do |k|
      v = buf[k]
      id = k.upcase.gsub(%r{[/.-]}, '_')
      if v == true
        f.printf "#define #{id} 1\n"
      else
        f.printf "/* #undef  #{id} */\n" 
      end
    end

    @defs.keys.sort.each { |x| f.printf "#define #{x} #{@defs[x]}\n" }

    f.close
  end

  # Generate the config.yaml dump of the current project state
  def write_config_yaml
    puts 'creating config.yaml'
    File.open('config.yaml', 'w') do |f|
      YAML.dump(self, f)
    end
  end

  # Generate a configure script
  def write_configure
    return if @custom_configure_script == true
    puts 'creating configure'
    File.unlink('configure') if File.exist?('configure')
    File.open('configure', 'w') do |f|
      f.puts '#!/bin/sh
#
# Copyright (c) 2013 Mark Heily <mark@heily.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
   
usage() {
cat << "EOF"
Usage: configure [options]

Installation options:
        --bindir [DIRECTORY]         TODO describe this [$(EPREFIX)/bin]
        --datadir [DIRECTORY]        TODO describe this [$(DATAROOTDIR)]
        --datarootdir [DIRECTORY]    TODO describe this [$(PREFIX)/share]
        --docdir [DIRECTORY]         TODO describe this [$(DATAROOTDIR)/doc/$(PACKAGE)]
        --eprefix [DIRECTORY]        TODO describe this [$(PREFIX)]
        --includedir [DIRECTORY]     TODO describe this [$(PREFIX)/include]
        --infodir [DIRECTORY]        TODO describe this [$(DATAROOTDIR)/info]
        --libdir [DIRECTORY]         TODO describe this [$(EPREFIX)/lib]
        --libexecdir [DIRECTORY]     TODO describe this [$(EPREFIX)/libexec]
        --localedir [DIRECTORY]      TODO describe this [$(DATAROOTDIR)/locale]
        --localstatedir [DIRECTORY]  TODO describe this [$(PREFIX)/var]
        --mandir [DIRECTORY]         TODO describe this [$(DATAROOTDIR)/man]
        --oldincludedir [DIRECTORY]  TODO describe this [/usr/include]
        --pkgconfigdir [DIRECTORY]   where to install pkg-config files [$(LIBDIR)/pkgconfig]
        --pkgdatadir [DIRECTORY]     TODO describe this [$(DATADIR)/$(PACKAGE)]
        --pkgincludedir [DIRECTORY]  TODO describe this [$(INCLUDEDIR)/$(PACKAGE)]
        --pkglibdir [DIRECTORY]      TODO describe this [$(LIBDIR)/$(PACKAGE)]
        --prefix [DIRECTORY]         TODO describe this [/usr/local]
        --sbindir [DIRECTORY]        TODO describe this [$(EPREFIX)/sbin]
        --sharedstatedir [DIRECTORY] TODO describe this [$(PREFIX)/com]
        --sysconfdir [DIRECTORY]     TODO describe this [$(PREFIX)/etc]

Project options:

System types:
        --build BUILD                set the system type for building
        --host HOST                  cross-compile programs to run on a different system type
        --target TARGET              build a compiler for cross-compiling

Optional Features:

Common options:
        --disable-static             Disable generation of static libraries
        --disable-option-checking
    -h, --help                       Show this message
    -V, --version                    Display version information and exit
EOF
}

err() {
    echo "*** ERROR ***  $*"
    exit 1
}

require_var() {
    key=$1
    eval "val=\$$key"
    if [ "$val" = "" ] ; then
       echo "ERROR: you must provide --$2 as a command line option"
       exit 1
    fi
}


echo "# Automatically generated by ./configure -- do not edit" > config.mk
for arg in $*
do
  if [ `echo "$arg" | grep "^--"` = "$arg" ] ; then
     key=`echo $arg | sed "s/^--//; s/=.*//; s/^with-//;"`
     val=`echo $arg | sed "s/.*=//"`
     uc_key=`echo "$key" | tr "a-z" "A-Z" | tr "-" "_"`
     case $key in
     "help")
       usage
       exit 1
       ;;
     bindir|datadir|datarootdir|docdir|includedir|infodir|libdir|libexecdir|localedir|localstatedir|mandir|pkgconfigdir|pkgdatadir|pkgincludedir|pkglibdir|prefix|sbindir|sharedstatedir|sysconfdir)
       echo "$uc_key=$val" >> config.mk
       ;;
     exec-prefix)
       echo "EPREFIX=$val" >> config.mk
       ;;
     program-prefix)
       if [ "$val" != "" ] ; then err "FIXME - not implemented" ; fi
       ;;
     disable-static)
       echo "$uc_key=1" >> config.mk
       ;;
     build|host)
       # TODO: we should split this up, and override the other Makeconf
       # variables like *_VENDOR, *_ARCH, *_CPU, *_KERNEL, *_SYSTEM 
       echo "$uc_key=$val" >> config.mk
       eval "${key}_system_type=\"$val\""
       ;;
     disable-option-checking)
        # Not implemented, this behavior is the default (for now)
        ;;
     disable-dependency-tracking)
        # Not implemented, dependency tracking is done in Ruby (for now)
        ;;
     # Android-specific variables
     ndk|sdk)
       echo "$uc_key=$val" >> config.mk
       eval "$key=\"$val\""
       ;;
     *)
       echo "Warning: unrecognized option: $arg"
       ;;
     esac
  fi
done

# Android-specific options
if [ "`echo ${host_system_type} | grep androideabi`" != "" ] ; then
    exec ./configure.rb $*
#    require_var ndk with-ndk
#    require_var sdk with-sdk
fi

printf "checking for a C compiler... "
for cmd in ${host_system_type}-cc cc gcc gcc4 clang
do
    $cmd --version >/dev/null 2>&1
    if [ $? -eq 0 ] ; then cc="$cmd" ; break ; fi
done
if [ -n "$CC" ] ; then cc="$CC" ; fi
if [ -n "$cc" ] ; then
    echo "$cc"
    echo "CC=$cc" >> config.mk
    if [ "$cc" != "cc" ] ; then echo "LD=$cc" >> config.mk ; fi
    if [ -n "$CFLAGS" ] ; then echo "CFLAGS=$CFLAGS" >> config.mk ; fi
else
    echo "not found"
    err "Please install a compiler and add it to your PATH"
fi

printf "checking for ar.. "
for ar in ${host_system_type}-ar ar gar
do
    $ar --version >/dev/null 2>&1
    if [ $? -eq 0 ] ; then ar="$ar" ; break ; fi
done
if [ -n "$ar" ] ; then
  echo "$ar"
  echo "AR=$ar" >> config.mk
else
    echo "not found"
    err "Please install an archiver and add it to your PATH"
fi

printf "checking for ranlib.. "
for ranlib in ${host_system_type}-ranlib ranlib
do
    $ar --version >/dev/null 2>&1
    if [ $? -eq 0 ] ; then ranlib="$ranlib" ; break ; fi
done
if [ -n "$ranlib" ] ; then
  echo "$ranlib"
  echo "RANLIB=$ranlib" >> config.mk
else
    echo "not found"
    err "Please install ranlib and add it to your PATH"
fi

printf "checking for a usable make command... "
for cmd in make gmake
do
    $cmd --version >/dev/null 2>&1
    if [ $? -eq 0 ] ; then make="$cmd" ; break ; fi
done
if [ -n "$make" ] ; then
    echo "yes"
    echo "MAKE=$make" >> config.mk
else
    echo "not found"
    err "Please install GNU Make and add it to your PATH as either make or gmake"
fi

# Allow additional variables from the environment to override the defaults
#
test -n "$LD" && echo "LD=$LD" >> config.mk
test -n "$LDFLAGS" && echo "LDFLAGS=$LDFLAGS" >> config.mk
# TODO: need to add Makefile support for: LIBS, CPP, CPPFLAGS

rm -f config.h
$make config.h
'
    f.chmod(0555)
    f.close
    end
  end

  # Add an additional Makefile target
  def target(t)
    throw ArgumentError.new('Invalid data type') unless t.kind_of?(Target) 
    @target.push t
  end

#XXX fixme -- testing
  def mount(uri,subdir)
    x = Net::HTTP.get(URI(uri))
    puts x.length
  end

  # Test if the project will build a library with a given pathname.
  # This is used for inter-dependency analysis
  def provides?(path)
    fn = File.basename(path)
    @build.each do |obj|
       if obj.respond_to?(:output)
         return true if obj.output == fn
       end
    end
    return false
  end    
end
