# Generates a pkgconfig '.pc' file

class PkgConfig < Buildable

  attr_accessor :name, :description, :version, :requires, :libs_private, :export_cflags

  def initialize(options = {})
    raise ArgumentError unless options.kind_of?(Hash)

    # pkgconfig variables
    @name = nil
    @description = 'No description'
    @version = '0.1'
    @requires = ''
    @libs_private = ''
    @export_cflags = ''

    options.each do |k,v|
      instance_variable_set('@' + k.to_s,v)
      # KLUDGE - parent constructor will barf unless we delete our 
      #       custom options
      options.delete k
    end

    super(options)
  end

  def makefile_hook(makefile)
    makefile.define_variable('PKGCONFIGDIR', '=', '$(LIBDIR)/pkgconfig')
  end

  def install(installer)
    installer.install(
        :sources => @name + '.pc',
        :dest => '$(PKGCONFIGDIR)',
        :mode => '644') 
  end

  def project_hook(proj)
    File.open("#{name}.pc.in", 'w') do |f|
       f.puts <<__EOF__

Name: #{@name}
Description: #{@description}
Version: #{@version}
Requires: #{@requires}
Libs: #{@libs}
Libs.private: #{@libs_private}
Cflags: #{@export_cflags}
__EOF__
    end
  end

  def compile(cc)
    input = @name + '.pc.in'
    output = @name + '.pc'
    mk = Makefile.new
    mk.add_target(output, [ 'config.h' ], [
            "@echo 'creating #{output}'",
            '@printf "prefix=$(PREFIX)\nexec_prefix=$(EPREFIX)\nlibdir=$(LIBDIR)\nincludedir=$(INCLUDEDIR)\n" > ' + output,
            "@cat #{@name}.pc.in >> #{output}"
            ])
    mk.distribute input

    mk.add_dependency('all',output)
    
    return mk
  end

  def link(ld)
  end

  def makedepends
    []
  end

end
