# A generic Header class that installs header files into $(PKGINCLUDEDIR)

class Header < Buildable

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)

    # KLUDGE - parent constructor will barf unless we delete our 
    #       custom options
    @namespace = options[:namespace]
    options.delete :namespace

    super(options)
  end

  def install(installer)
    dest = '$(INCLUDEDIR)'
    dest += '/' + @namespace unless @namespace.nil?

    installer.install(
        :sources => @sources,
        :dest => dest,
        :mode => '644') 
  end

  def compile(cc)
    mk = Makefile.new
    mk.distribute(@sources)
    return mk
  end

  def link(ld)
  end

  def makedepends
    []
  end

end
