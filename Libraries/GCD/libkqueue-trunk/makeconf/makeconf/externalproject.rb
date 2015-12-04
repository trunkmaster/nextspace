# An external project is typically a third-party library dependency
# that does not use makeconf for it's build system.
#
class ExternalProject < Buildable
 
  require 'net/http'
  require 'uri'

  attr_accessor :uri, :patch

  def initialize(options)
    # KLUDGE - parent constructor will barf unless we delete our 
    #       custom options
    @uri = options[:uri]
    options.delete :uri
    @configure = options[:configure]  # options passed to ./configure 
    options.delete :configure
    @configure = './configure' if @configure.nil?
    @patch = options[:patch]
    options.delete :patch
    @patch = [] if @patch.nil?

    super(options)

    @installable = false
    @distributable = false
  end

  # Examine the operating environment and set configuration options
  def configure
    printf "checking for external project #{@id}... "
    if File.exists?(@id)
       puts "yes"
    else
      puts "no"
      download

      # Apply patches
      @patch.each do |p|
        system "cd #{@id} && patch -p0 -N < ../#{p}" \
            or throw "failed to apply patch: ../#{p}"
      end
    end

    # KLUDGE: passthrough certain options
    passthru = []
    Makeconf.original_argv.each do |x|
      passthru.push x if x =~ /^--(host|with-ndk|with-sdk)/
    end
    @configure += ' ' + passthru.join(' ') unless passthru.empty?

    # FIXME: this works, but autotools differ widely across host systems.
    #        make this an optional step that can be done
    #
    # Regenerate the Autotools files
    #if File.exists?(@id + '/configure.ac')
    #      system "cd #{@id} && autoreconf -fvi" \
    #          or throw "autoreconf failed"
    #    end

    # Run the autoconf-style ./configure script
    puts "*** Configuring #{@id} using #{@configure}"
    system "cd #{@id} && #{@configure}" \
        or throw "Unable to configure #{@id}"
    puts "*** Done"
  end

  def compile(cc)
     makefile = Makefile.new
     return makefile unless @buildable
     makefile.add_dependency('all', "#{@id}-build-stamp")
     makefile.add_target("#{@id}-build-stamp", [], 
             [
             "cd #{@id} && make",
             "touch #{@id}-build-stamp",
             ])
     makefile.add_rule('check', [ "cd #{@id} && make check" ])
     makefile.add_rule('clean', Platform.rm("#{@id}-build-stamp"))
     makefile
  end

  def link(ld)
  end


private

  # Download the project from an external source
  def download

#example for tarball
#    x = Net::HTTP.get(URI(uri))
#  end
    uri = URI(@uri)

    case uri.scheme
    when 'svn', 'svn+ssh'
      puts "downloading #{@uri}.. "
      system "svn co #{@uri} #{@id}" or throw "Unable to checkout working copy"
    when 'file'
      puts "unpacking #{uri.host}.. "
      system "tar zxf #{uri.host}" or throw "Unable to unpack #{uri.host}"
    else
      throw "Unsupported URI scheme #{@uri}"
    end
  end

  def log
      Makeconf.logger
  end
end
