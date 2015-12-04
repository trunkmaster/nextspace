class AndroidProject < BaseProject

  attr_accessor :target_arch,
                :target_arch_abi, 
                :target_abi, 
                :target_platform

  def initialize(options)
    super(options)

    # Public
    @target_platform = 'android-14'
    @target_arch = 'arm'
    @target_arch_abi = 'armeabi'
    @target_abi = 'armeabi-v7a'
    @ndk_path = nil
    @sdk_path = nil

    # Private
    @prebuilt_libs = []

    # KLUDGE: We need to know the NDK and SDK paths very early on.
    # Peek at the original ARGV to find them.
    Makeconf.original_argv.each do |arg|
      if arg =~ /^--with-ndk=(.*)/
         @ndk_path = $1
      end
      if arg =~ /^--with-sdk=(.*)/
         @sdk_path = $1
      end
    end

    self.ndk_toolchain_version = '4.6'
  end

  # Parse ARGV options
  # Should only be called from Makeconf.parse_options()
  # Note that ndk_path and sdk_path are previously parsed during initialize()
  def parse_options(opts)
    super(opts)

    opts.separator ""
    opts.separator "Android options:"

    opts.on('--with-ndk=DIRECTORY', "Path to the Android NDK") do |arg|
       @ndk_path = arg
    end
    opts.on('--with-sdk=DIRECTORY', "Path to the Android SDK") do |arg|
       @sdk_path = arg
    end

  end

  def ndk_toolchain_version
    @ndk_toolchain_version
  end

  def ndk_toolchain_version=(version)
    @ndk_toolchain_version = version

    if version =~ /^clang/
      ndk_cc = toolchain_binary('clang')
    else
      ndk_cc = toolchain_binary('gcc')
    end

    #FIXME -overwrites previous Compiler object
    @cc = CCompiler.new(
            :search => ndk_cc
            ) 
    @cc.sysroot = ndk_sysroot
    @cc.platform_cflags = cflags(cc.path)

    # Clang uses an alternate linker
    if version =~ /^clang/
      ld = Linker.new
      ld.path = @ndk_path + '/toolchains/llvm-3.2/prebuilt/linux-x86/bin/clang++'
      ld.platform_ldflags = [ '-Wl,--gc-sections', 
      '-Wl,-z,nocopyreloc',
      "--sysroot=#{@ndk_path}/platforms/android-14/arch-arm",
      # FIXME: might need to put in ldadd
      "-gcc-toolchain #{@ndk_path}/toolchains/arm-linux-androideabi-4.6/prebuilt/linux-x86",
      "-target armv7-none-linux-androideabi",
      "-Wl,--fix-cortex-a8",
      "-Wl,--no-undefined",
      "-Wl,-z,noexecstack",
      "-Wl,-z,relro",
      "-Wl,-z,now" ]
      @cc.ld = ld
    end
  end

  def preconfigure

    printf 'checking for the Android NDK.. '
    throw 'Unable to locate the NDK. Please set the --with-ndk variable to the correct path' if @ndk_path.nil?
    puts @ndk_path
    printf 'checking for the Android SDK.. '
    throw 'Unable to locate the SDK. Please set the --with-sdk variable to the correct path' if @sdk_path.nil?
    puts @sdk_path
  end

  def to_make

    write_android_mk
    write_application_mk

    # Generate the ndk-build command
    ndk_build = '$(NDK)/ndk-build V=1 NDK_DEBUG=1 NDK_PROJECT_PATH=.'
    unless @ndk_toolchain_version.nil?
      ndk_build += " NDK_TOOLCHAIN_VERSION=#{@ndk_toolchain_version}"
    end

    mf = super

    mf.define_variable('NDK_LIBDIR', ':=', ndk_libdir)
    mf.define_variable('NDK', '?=', @ndk_path)
    mf.define_variable('SDK', '?=', @sdk_path)
    mf.define_variable('GDB', '?=', toolchain_binary('gdb'))
    mf.define_variable('ADB', '?=', '$(SDK)/platform-tools/adb')
    mf.target('all').rules.push ndk_build
    
    # Copy objects from obj/ to the top level, to match the behavior
    # of non-Android platforms
    # FIXME: this is very crude and should use the actual :output filenames
    #        also, it will only copy libraries and not executables
    #
    mf.target('all').rules.push 'cp obj/local/*/*.a obj/local/*/*.so .'

    # Generate the 'make clean' target
    mf.target('clean').rules = [ ndk_build + ' clean' ]

    # Generate the 'make check' target
    mf.target('check').deps = []        # FIXME: should depend on 'all'
    @build.each do |obj|
      if obj.kind_of?(Test)
        mf.target('check').rules.push([
          '$(ADB) push libs/' + @target_abi + '/' + obj.output + ' /data/local/tmp',
          '$(ADB) shell chmod 751 /data/local/tmp/' + obj.output,
          '$(ADB) shell /data/local/tmp/' + obj.output,
          '$(ADB) shell rm /data/local/tmp/' + obj.output
          ])
      end
    end

    # Run a $(BINARY) under the Android debugger
    # see: http://www.kandroid.org/online-pdk/guide/debugging_gdb.html
    mf.add_target('debug', [], [
         '$(ADB) forward tcp:5039 tcp:5039',
         '$(ADB) push $(BINARY) /data/local/tmp',
         '$(ADB) shell chmod 751 /data/local/tmp/`basename $(BINARY)`',
         '$(ADB) shell gdbserver :5039 /data/local/tmp/`basename $(BINARY)` &',
         'sleep 2', # give gdbserver time to start
  
          # Pull things from the device that are needed for debugging
          '$(ADB) pull /system/bin/linker obj/local/armeabi/linker',
          '$(ADB) pull /system/lib/libc.so obj/local/armeabi/libc.so',
          '$(ADB) pull /system/lib/libm.so obj/local/armeabi/libm.so',
          '$(ADB) pull /system/lib/libstdc++.so obj/local/armeabi/libstdc++.so',
  
         'echo "set solib-search-path obj/local/armeabi" > .gdb-commands',
         'echo "target remote :5039" >> .gdb-commands',
         '$(GDB) -x .gdb-commands $(BINARY)',
         'rm .gdb-commands',
         ])
  
    # Connect to the device and run a shell
    # TODO: add to makeconf
    mf.add_target('shell', [], [ '$(ADB) shell' ])

    mf
  end

  # Return the path to the Android NDK system root
  def ndk_sysroot
     @ndk_path + '/platforms/' + @target_platform + '/arch-' + @target_arch
  end

  # Return the path to the Android NDK /usr/lib 
  def ndk_libdir
     ndk_sysroot + '/usr/lib/'
  end

  # Return additional cflags needed by the compiler
  def cflags(cc_path)
    res = []
    if cc_path =~ /clang/
      res.push '-gcc-toolchain', @ndk_path + '/toolchains/arm-linux-androideabi-4.6/prebuilt/linux-x86'
      res.push '-isystem', @ndk_path + '/toolchains/llvm-3.2/prebuilt/linux-x86/lib/clang/3.2/include'
      res.push %w{ -ffunction-sections -funwind-tables -fstack-protector -D__ARM_ARCH_5__ -D__ARM_ARCH_5T__ -D__ARM_ARCH_5E__ -D__ARM_ARCH_5TE__ -target armv7-none-linux-androideabi -march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16 -mthumb -Os -fomit-frame-pointer -fno-strict-aliasing -I. -DANDROID -fblocks -D_GNU_SOURCE -D__BLOCKS__ -Wa,--noexecstack -O0 -g }
      res.push "-I#{@ndk_path}/platforms/android-14/arch-arm/usr/include"
    end
    res.flatten
  end

private

  # Create the Android.mk makefile
  def write_android_mk
    ofile = 'Android.mk'
    buf = [
      '# Automatically generated by ./configure -- do not edit',
      '',
      'TARGET_PLATFORM := ' + @target_platform,
      'TARGET_ARCH_ABI := ' + @target_arch_abi,
      'LOCAL_PATH := $(call my-dir)',
      '',
    ]

    @build.each do |obj|
      next if obj.kind_of? Header
      next if obj.kind_of? ExternalProject 
      buf.push 'include $(CLEAR_VARS)',
            '';

      id = obj.id
      id += '-static' if obj.kind_of? StaticLibrary

      buf.push "LOCAL_MODULE    := #{id}"
      buf.push "LOCAL_MODULE_FILENAME := #{obj.id}" if obj.kind_of? StaticLibrary
      buf.push "LOCAL_SRC_FILES := " + obj.expand_sources(obj.sources).join(' ')
      buf.push "LOCAL_CFLAGS    := " + obj.cflags.join(' ')
      buf.push translate_ldadd(obj.ldadd) if obj.ldadd
      buf.push ''
      case obj.class.to_s
      when 'StaticLibrary'
        buf.push 'include $(BUILD_STATIC_LIBRARY)'
      when 'SharedLibrary'
        buf.push 'include $(BUILD_SHARED_LIBRARY)'
      when 'Binary', 'Test'
        buf.push 'include $(BUILD_EXECUTABLE)'
      when 'Manual', 'PkgConfig'
        # NOOP: These are not used on Android
      else
        throw "Unsuported class #{obj.class}"
      end
      buf.push ''
    end

    buf.push prebuilt_libraries

    puts 'creating ' + ofile
    f = File.open(ofile, 'w')
    buf.each do |str|
      f.printf "#{str}\n" 
    end
    f.close
  
  end

  # Create the jni/Application.mk makefile
  def write_application_mk
    ofile = 'jni/Application.mk'
    buf = [
      '# Automatically generated by ./configure -- do not edit',
      'APP_PROJECT_PATH := .',
      'APP_BUILD_SCRIPT := $(APP_PROJECT_PATH)/Android.mk',
      'APP_PLATFORM     := ' + @target_platform,
      'APP_ABI          := ' + @target_abi,
      'APP_OPTIM        := debug',
    ]

    Dir.mkdir 'jni' unless File.exists?('jni')
    puts 'creating ' + ofile
    f = File.open(ofile, 'w')
    buf.each do |str|
      f.printf "#{str}\n" 
    end
    f.close
  end

private

  # Translate LDADD flags into the corresponding Android.mk prebuilt definitions
  def prebuilt_libraries
    buf = []
    @build.each do |obj|
    # TODO: shared libs
      obj.ldadd.each do |item|
        next if provides?(item) or item =~ /^obj\/local\//
        prebuilt = File.basename(item).sub(/\.a$/, '-prebuilt')
        if item =~ /\.a$/ and item =~ /\// and not @prebuilt_libs.include? prebuilt
           # FIXME: assumes it is a prebuilt library in a different path
           buf.push('',
              'include $(CLEAR_VARS)',
              'LOCAL_MODULE := ' + File.basename(item).sub(/\.a$/, '-prebuilt'),
              'LOCAL_SRC_FILES := ' + item,
              'include $(PREBUILT_STATIC_LIBRARY)'
              )
           @prebuilt_libs.push prebuilt
        end
      end
    end
    buf.join "\n"
  end

  # Translate LDADD flags into the corresponding Android.mk variables
  def translate_ldadd(ldadd)
     static_libs = []
     # TODO: shared libs
     ldadd.each do |item|
       if item =~ /\.a$/ 
          if provides?(item) or item =~ /^obj\/local\//
            static_libs.push File.basename(item).sub(/\.a$/, '-static')
          else
            static_libs.push File.basename(item).sub(/\.a$/, '-prebuilt')
          end
       end
     end
     
     buf = ''
     buf += 'LOCAL_STATIC_LIBRARIES := ' + static_libs.join(' ') if static_libs
     buf
  end

  # Determine the path to the Android NDK
  def find_ndk()
    [ ENV['NDK'] ].each do |x|
      if !x.nil? and File.exists?(x)
        return x
      end
    end
    nil
  end

  # Return the full path to a prebuilt binary in the toolchain
  #
  def toolchain_binary(file)

    # Determine the type of prebuilt binary to use
    if RbConfig::CONFIG['host_os'] =~ /linux/
      build_os = 'linux-x86';
    elsif RbConfig::CONFIG['host_os'] =~ /darwin/
      build_os = 'darwin-x86';
    else
      throw 'Unknown build OS: ' + RbConfig::CONFIG['host_os']
    end

    # Special case:
    #   Clang does not follow the same conventions as GCC
    #   This is hardcoded for NDK r8e
    if file == 'clang'
      return @ndk_path + '/toolchains/llvm-3.2/prebuilt/' + build_os + '/bin/clang'
    else
    return @ndk_path +
       '/toolchains/'+ @target_arch + '-linux-androideabi-' +
       @ndk_toolchain_version +
       '/prebuilt/' +
       build_os +
            '/bin/' + @target_arch + '-linux-androideabi-' + file
    end
  end

end

#--------------------------------------------------------------------#
#
# Overrides of other classes

class Buildable
  def compile(cc)
  end
  def link(ld)
  end
end

class StaticLibrary
  def compile(cc)
  end
  def link(ld)
  end
end

class Test
  def compile(cc)
  end
  def link(ld)
  end
end

