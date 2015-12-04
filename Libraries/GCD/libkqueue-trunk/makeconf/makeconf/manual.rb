# Generates program manuals (man pages, etc.)
# Currently it only handles troff/mdoc manpages, but in the future it could
# generate multiple formats from a single source

class Manual < Buildable

  def initialize(source, options = {})
    raise ArgumentError unless options.kind_of?(Hash)
    @source = source

    # Determine the manpage options
    @man = {
        :section => @source.sub(/^.*\./, ''),
        :alias => options[:alias] || []
    }
    @man[:alias] = [ @man[:alias] ] unless @man[:alias].kind_of?(Array)

    # KLUDGE - parent constructor will barf unless we delete our 
    #       custom options
    options.delete :alias

    super(options)
  end

  def install(installer)
    outfile = '$(MANDIR)/man' + @man[:section]
    installer.install(
        :sources => @source,
        :dest => outfile,
        :mode => '644') 

    @man[:alias].each do |a|
      aliasfile = "\$(MANDIR)/man" + @man[:section] + '/' + a
      installer.add_rule "rm -f \$(DESTDIR)#{aliasfile}"
      installer.add_rule("ln -s #{@source} \$(DESTDIR)#{aliasfile}")
      # XXX-FIXME need to add uninstall rule
    end
  end

  def compile(cc)
    mk = Makefile.new
    mk.distribute(@source)
    return mk
  end

  def link(ld)
  end

  def makedepends
    []
  end

end
