# A generic Library class that builds both shared and static

class Library < Buildable

  attr_reader :buildable

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    @buildable = [SharedLibrary.new(options), StaticLibrary.new(options)]
  end

end

class SharedLibrary < Buildable

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    id = options[:id]

    super(options)
    @abi_major = 0
    @abi_minor = 0
    @output = id + Platform.shared_library_extension
    @output = 'lib' + @output unless @output =~ /^lib/ or Platform.is_windows?
    @output_type = 'shared library'
#FIXME: @cc.ld.flags.push('-export-dynamic') unless Platform.is_solaris?
  end

  def install(installer)
    outfile = "#{@output}.#{@abi_major}.#{@abi_minor}"
    installer.install(
        :dest => '$(LIBDIR)',
        :rename => outfile,
        :sources => @output,
        :mode => '0644'
    )
    installer.add_rule "rm -f \$(DESTDIR)\$(LIBDIR)/#{output}"
    installer.add_rule "ln -s #{outfile} \$(DESTDIR)\$(LIBDIR)/#{output}"
    installer.add_rule "rm -f \$(DESTDIR)\$(LIBDIR)/#{output}.#{@abi_major}"
    installer.add_rule "ln -s #{outfile} \$(DESTDIR)\$(LIBDIR)/#{output}.#{@abi_major}"
  end

  def link(ld)
    ld.shared_library = true
    ld.soname = "#{@output}.#{@abi_major}"
    super(ld)
  end

end

class StaticLibrary < Buildable

  # Controlled by the --enable-static command line argument
  @@enable_static = true

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    id = options[:id]
    super(options)
    @output = id + Platform.static_library_extension
    @output = 'lib' + @output unless @output =~ /^lib/ or Platform.is_windows?
    @output_type = 'static library'
    @buildable = @@enable_static

# FIXME: clashes with shared objects
#      src = d.sub(/-static#{Platform.object_extension}$/, '.c')
  end

  def install(installer)
    # NOOP - No reason to install a static library
  end

  def link(ld)
    makefile = Makefile.new
    ar = @project.ar
    ar.output = self.output
    ar.objects = self.objects
    makefile.add_target ar.to_make

    makefile.add_dependency('all', output)
    makefile.clean(output)

    return makefile
  end

  def StaticLibrary.disable_all
    @@enable_static = false
  end
end

#
# UnionLibrary - combine multiple static libraries into a single library.
#
#   The :sources for this library should be an array of Library objects
#
class UnionLibrary < Library

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    @buildable = []
    options[:sources].each do |x|
      x.buildable.each do |y|
        @buildable.push y if y.kind_of?(StaticLibrary)
      end
    end
    @buildable.flatten!

    # Build a list of all source files within each component library
    sources = []
    @buildable.each { |x| sources.push x.sources }
    sources.flatten!

    @buildable.push StaticLibrary.new(
            :id => options[:id],
            :sources => sources
            )
  end
end
