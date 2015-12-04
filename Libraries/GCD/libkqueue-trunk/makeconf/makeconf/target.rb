# A target is a section in a Makefile
class Target

  attr_reader :objs
  attr_accessor :deps, :rules

  def initialize(objs, deps = [], rules = [])
      deps = [ deps ] if deps.kind_of?(String)
      rules = [ rules ] if rules.kind_of?(String)
      raise ArgumentError.new('Bad objs') unless objs.kind_of?(String)
      raise ArgumentError.new('Bad deps') unless deps.kind_of?(Array)
      raise ArgumentError.new('Bad rules') unless rules.kind_of?(Array)

      @objs = objs
      @deps = deps
      @rules = rules
      @dirs_to_create = []      # directories to create
      @files_to_copy = {}       # files to be copied
  end

  # Merge one target with another
  def merge!(src)
      raise ArgumentError.new('Mismatched object') \
          unless src.objs == @objs
      @deps.push(src.deps).uniq!
      @rules.push(src.rules).flatten!
      @dirs_to_create.push(src.dirs_to_create).flatten!.uniq!
      src.files_to_copy.each do |k,v|
        @files_to_copy[k] ||= []
        @files_to_copy[k].concat(v).uniq!
      end
  end

  # Ensure that a directory is created before any rules are evaluated
  def mkdir(path)
    @dirs_to_create.push(path) unless @dirs_to_create.include?(path)
  end

  # Copy a file to a directory. This is more efficient than calling cp(1)
  # for each file.
  def cp(src,dst)
    @files_to_copy[dst] = [] unless @files_to_copy.has_key? dst
    @files_to_copy[dst].push(src)
  end

  def add_dependency(depends)
    @deps.push(depends).uniq!
  end

  def add_rule(rule)
    @rules.push(rule)
  end

  def prepend_rule(target,rule)
    @rules.unshift(rule)
  end

  # Return the string representation of the target
  def to_s
    res = "\n" + @objs + ':'
    res += ' ' + @deps.uniq.join(' ') if @deps
    res += "\n"
    @dirs_to_create.each do |dir|
       res += "\t" + Platform.mkdir(dir) + "\n"
    end
    @files_to_copy.each do |k,v|
       res += "\t" + Platform.cp(v, k) + "\n"
    end
    @rules.each do |r| 
      if r.kind_of?(String)
        res += "\t" + r + "\n"
      else
        res += r.to_s
      end
    end
    res
  end

  protected

  attr_reader :dirs_to_create, :files_to_copy
end

# Uses a conditional like ifeq() to conditionally execute one or more rules
# TODO: support BSD syntax like: .if $var = $cond
#
class Target::ConditionalRule

  def initialize(rules)
    @condition = nil
    @rules = rules
  end

  def ifeq(var,match)
    @condition = "ifeq (#{var},#{match})"
    self
  end

  def ifneq(var,match)
    @condition = "ifneq (#{var},#{match})"
    self
  end

  def ifdef(var)
    @condition = "ifdef (#{var})"
    self
  end

  def to_s
    rules = "#{@condition}\n"
    @rules.each { |r| rules += "\t#{r}\n" }
    rules += "endif\n"
    rules
  end
end
