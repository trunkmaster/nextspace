# An installer copies files from the current directory to an OS-wide location
class Installer

  attr_reader :dir
  attr_accessor :package

  def initialize
    @items = []         # Items to be installed
    @project = nil
    @path = nil
    @custom_rule = []       # Custom rules to run at the end

    # Set default installation paths
    @dir = {
        :prefix => Platform.is_superuser? ? '/usr' : '/usr/local',
        :eprefix => '$(PREFIX)',    # this is --exec-prefix
        :bindir => '$(EPREFIX)/bin',
        :datarootdir => '$(PREFIX)/share',
        :datadir => '$(DATAROOTDIR)',
        :docdir => '$(DATAROOTDIR)/doc/$(PACKAGE)',
        :includedir => '$(PREFIX)/include',
        :infodir => '$(DATAROOTDIR)/info',
        :libdir => '$(EPREFIX)/lib',
        :libexecdir => '$(EPREFIX)/libexec',
        :localedir => '$(DATAROOTDIR)/locale',
        :localstatedir => '$(PREFIX)/var',
        :mandir => '$(DATAROOTDIR)/man',
        :oldincludedir => '/usr/include',
        :sbindir => '$(EPREFIX)/sbin',
        :sysconfdir => '$(PREFIX)/etc',
        :sharedstatedir => '$(PREFIX)/com',

        # Package-specific directories
        :pkgincludedir => '$(INCLUDEDIR)/$(PACKAGE)',
        :pkgdatadir => '$(DATADIR)/$(PACKAGE)',
        :pkglibdir => '$(LIBDIR)/$(PACKAGE)',
        
        #TODO: document this
        #DEPRECATED: htmldir, dvidir, pdfdir, psdir
    }

    @dir[:prefix] = ENV['SystemDrive'] + @dir[:prefix] if Platform.is_windows?
  end

  # Examine the operating environment and set configuration options
  def configure(project)
    @project = project
    printf 'checking for a BSD-compatible install.. '
    if Platform.is_windows?
       puts 'not found'
    else
       @path = search() or throw 'No installer found'
       printf @path + "\n"
    end
  end

  # Parse command line options.
  # Should only be called from Makeconf.parse_options()
  def parse_options(opts)
    opts.separator ""
    opts.separator "Installation options:"

    # Convert symbols to strings
    tmp = {}
    @dir.each { |k,v| tmp[k.to_s] = v }

    tmp.sort.each do |k, v|
       opts.on('--' + k + ' [DIRECTORY]', "TODO describe this [#{v}]") do |arg|
          @dir[k.to_sym] = arg
       end
    end

  end

  # Register a file to be copied during the 'make install' phase.
  def install(src)
    buf = {
        :sources => nil,
        :dest => nil,
        :rename => nil,
        :directory? => false,
        :group => nil,
        :user => nil,
        :mode => '0755',
    }
#TODO: check for leading '/': raise ArgumentError, 'absolute path is required' unless src[:dest].index(0) == '/'
    raise ArgumentError, ':dest is require' if src[:dest].nil?
    raise ArgumentError, 'Cannot specify both directory and sources' \
       if buf[:directory] == true and not buf[:sources].nil
    @items.push buf.merge(src)
  end

  def to_make
    mkdir_list = []   # all directories that have been created so far

    m = Makefile.new
    m.define_variable('INSTALL', '?=', @path) unless @path.nil?
    @dir.keys.each { |d| m.define_variable(d.to_s.upcase, '=', @dir[d]) }

    # Add 'make install' rules
    @items.each do |i| 
      # Automatically create the destination directory, if needed
      destdir = expand_dir(i[:dest])
      unless mkdir_list.include?(destdir)
       m.add_rule('install', Platform.is_windows? ?
               "dir $(DESTDIR)#{destdir} >NUL 2>NUL || mkdir $(DESTDIR)#{destdir}" : 
               "/usr/bin/test -e $(DESTDIR)#{destdir} || $(INSTALL) -d -m 755 $(DESTDIR)#{destdir}")
       mkdir_list.push(destdir)
      end

      m.add_rule('install', install_command(i)) 
      m.add_rule('uninstall', uninstall_command(i)) 
    end

    # Add any custom rules at the end
    @custom_rule.each { |rule| m.add_rule('install', rule) }

    return m
  end

  # Return a list of files that will be installed
  def package_manifest()
    res = []
    @items.each do |item|
      sources = item[:sources]
      sources = [ sources ] unless sources.kind_of?(Array)
      sources.each do |src|
        # TODO - want to split into multiple packages
        #if pkg == :main
        #  next unless item[:dest] =~ /(LIB|BIN)DIR/
        #elsif pkg == :devel
        #  next unless item[:dest] =~ /(INCLUDE|MAN)DIR/
        #else
        #  throw "bad pkg type"
        #end
        dst = expand_dir(item[:dest])
        if item[:rename].nil?
          dst += '/' + src
        else
          dst += '/' + item[:rename]
        end
        dst.gsub!(/^\/usr\/local\//, '/usr/')  # KLUDGE: only true when making an RPM or DEB
        res.push dst
      end
    end
    res.join "\n"
  end

  # Add a custom rule to run at the end of the `install' target.
  def add_rule(rule)
    @custom_rule.push rule
  end

  private

  # Expand makefile variables related to installation directories
  # This is only useful on Windows, which lacks the install(1) command
  # and might (in the future) use something other than nmake to perform
  # the installation.
  #
  def expand_dir(s)
    return s unless Platform.is_windows?
    buf = s

    throw 'FIXME -- handle $(PACKAGE)' if buf =~ /\$\(PACKAGE\)/
    while buf =~ /\$/
      old = buf.dup
      @dir.each do |k,v|
        buf.gsub!(/\$\(#{k.to_s.upcase}\)/, v)
      end
      # Crude way of bailing out when there are undefined variables
      # like $(DESTDIR)
      break if old == buf and buf =~ /\$\(/
    end

    Platform.pathspec(buf)
  end

  # Translate an @item into the equivalent shell command(s)
  def install_command(h)
    res = []
    h[:sources] = [ h[:sources] ] if h[:sources].kind_of? String

    # TODO: more sanity checks (e.g. !h[:directory] && h[:sources])

    if Platform.is_windows?
      # XXX-this is not fully implemented, need mode/owner/group
      if h[:directory]
        res.push 'mkdir $(DESTDIR)' + expand_dir(h[:dest])
      else
        res.push "copy" 
        h[:sources].each do |src|
          res.push Platform.pathspec(src)
        end
        res.push '$(DESTDIR)' + expand_dir(h[:dest])
      end
    else
      res.push '$(INSTALL)'
      res.push '-d' if h[:directory]
      res.push('-m', h[:mode]) if h[:mode]
      res.push('-o', h[:owner]) if h[:owner]
      res.push('-g', h[:group]) if h[:group]
      h[:sources].each do |src|
        res.push Platform.pathspec(src)
      end
      dst = '$(DESTDIR)' + expand_dir(h[:dest])
      dst += '/' + h[:rename] unless h[:rename].nil?
      res.push dst
    end

    res.join(' ')
  end

  # Translate an @item into the equivalent uninstallation shell command(s)
  def uninstall_command(h)
    res = []

    h[:sources] = [ h[:sources] ] if h[:sources].kind_of?(String)

    # TODO: use Platform abstractions instead of duplicate logic
    if Platform.is_windows?
      unless h[:sources]
        res.push 'del', Platform.pathspec('$(DESTDIR)' + h[:dest])
      else
        h[:sources].each do |src|
          res.push 'del', Platform.pathspec('$(DESTDIR)' + h[:dest] + '/' + File.basename(src) )
        end
      end
    else
      unless h[:sources]
        res.push 'rmdir', '$(DESTDIR)' + h[:dest]
      else
        res.push 'rm', '-f', h[:sources].map { |x| '$(DESTDIR)' + h[:dest] + '/' + x }
      end
    end

    res.join(' ')
  end

  def search()
    [ ENV['INSTALL'], '/usr/ucb/install', '/usr/bin/install' ].each do |x|
        if !x.nil? and File.exists?(x)
         return x
        end
    end
  end

end
