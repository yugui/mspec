require 'mspec/runner/mspec'
require 'mspec/runner/actions/tally'
autoload :Config, 'rbconfig'

unless defined?(RUBY_NAME) and RUBY_NAME
  if defined?(RUBY_ENGINE) and RUBY_ENGINE
    RUBY_NAME = RUBY_ENGINE
  else
    RUBY_NAME = Config::CONFIG["RUBY_INSTALL_NAME"] || Config::CONFIG["ruby_install_name"]
  end
end
unless defined?(RUBY_EXE) and RUBY_EXE
  # detects path to the current interpreter;
  #  1) ARG0 if available
  #  2) path to the built binary if in a source tree
  #  3) $(bindir)/$(RUBY_INSTALL_NAME) if executable
  #  otherwise, simply uses RUBY_NAME and prays that it is in PATH.
  if defined?(ARG0) and ARG0 != File.basename(ARG0)
    RUBY_EXE = ARG0
  else
    binname = RUBY_NAME + (Config::CONFIG['EXEEXT'] || Config::CONFIG['exeext'] || '')
    case defined?(RUBY_ENGINE) && RUBY_ENGINE
    when 'rbx'   then bindir, binname = 'shotgun', 'rubinius'
    when 'jruby' then bindir = 'bin'
    else              bindir = '.'
    end

    path = File.join(bindir, binname)
    if File.exist?(path) && File.executable?(path)
      RUBY_EXE = path
    elsif path = File.join(Config::CONFIG['bindir'], binname) and 
      File.exist?(path) && File.executable?(path) then
      RUBY_EXE = path
    else
      RUBY_EXE = RUBY_NAME
    end
  end
end

class SpecGuard
  def self.register
    unless @registered
      @tally = TallyAction.new
      @tally.register
      MSpec.register :finish, self
      @registered = true
    end
  end

  def self.unregister
    @tally.unregister if @tally
  end

  def self.finish
    print "\n#{self.class}\n#{@tally.format}\n"
  end

  def initialize(*args)
    @args = args
  end

  def yield?(invert=false)
    if MSpec.report_mode?
      self.class.register
      MSpec.register :before, self
      return true
    elsif MSpec.verify_mode?
      self.class.register
      MSpec.register :after, self
      return true
    end
    return match? ^ invert
  end

  def ===(other)
    true
  end

  def before(state)
  end

  def after(state)
  end

  def unregister
    MSpec.unregister :before, self
    MSpec.unregister :after, self
    MSpec.unregister :exclude, self
    self.class.unregister
  end

  def implementation?(*args)
    args.any? do |name|
      !!case name
      when :rbx, :rubinius
        RUBY_NAME =~ /^rbx/
      when :ruby
        RUBY_NAME =~ /^ruby/
      when :ruby18
        RUBY_NAME =~ /^ruby(1.8)?/ and RUBY_VERSION =~ /^1.8/
      when :ruby19
        RUBY_NAME =~ /^ruby(1.9)?/ and RUBY_VERSION =~ /^1.9/
      when :jruby
        RUBY_NAME =~ /^jruby/
      when :ironruby, :ir
        RUBY_NAME =~ /^ironruby/
      else
        false
      end
    end
  end

  def windows?(sym, key)
    sym == :windows && !!key.match(/(mswin|mingw)/)
  end

  def platform?(*args)
    args.any? do |platform|
      if platform != :java && RUBY_PLATFORM.match('java') && os?(platform)
        true
      else
        RUBY_PLATFORM.match(platform.to_s) || windows?(platform, RUBY_PLATFORM)
      end
    end
  end

  def wordsize?(size)
    size == 8 * 1.size
  end

  def os?(*oses)
    require 'rbconfig'
    oses.any? do |os|
      host_os = Config::CONFIG['host_os'] || RUBY_PLATFORM
      host_os.downcase!
      host_os.match(os.to_s) || windows?(os, host_os)
    end
  end

  def match?
    implementation?(*@args) or platform?(*@args)
  end
end
