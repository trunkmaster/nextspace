# Detect the build system type and allow for cross-compilation
#
class SystemType

  # FIXME: detect 'build' properly
  @@build = RbConfig::CONFIG['host_os']
  @@host = nil
  @@target = nil

  ARGV.each do |arg|
    case arg
    when /^--build=(.*)$/
      @@build = $1
      puts "determining build system type.. #{@@build}"
    when /^--host=(.*)$/
      @@host = $1
      puts "determining host system type.. #{@@host}"
    when /^--target=(.*)$/
      @@target = $1
    end
  end

  def SystemType.build
    @@build
  end

  def SystemType.host
    @@host
  end

  def SystemType.target
    @@target
  end

end
