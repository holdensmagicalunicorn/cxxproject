require 'yaml'

class Hash
  def method_missing(m, *args, &block)
    fetch(m.to_s, nil)
  end
  def recursive_merge(h)
    self.merge!(h) {|key, _old, _new| if _old.class == Hash then _old.recursive_merge(_new) else _new end  } 
  end

end

class Toolchain
  attr_reader :toolchain
  def initialize(toolchain_file)
    @toolchain = YAML::load(File.open(toolchain_file))
    if @toolchain.base
      @based_on = @toolchain.base
    else
      @based_on = "base"
    end
    basechain = YAML::load(File.open(File.join(File.dirname(__FILE__),"#{@based_on}.json")))
    @toolchain = basechain.recursive_merge(@toolchain)
  end
  def method_missing(m, *args, &block)  
    if @toolchain[m.to_s]
      @toolchain[m.to_s]
    else
      puts "There's no method called #{m} here -- please try again."  
    end
  end  

  def add_to_list(path, x)
    setting = @toolchain
    path.each do |p|
      setting = setting[p]
    end
    throw "#{path.join('.')} is not an array" unless setting.class == Array
    setting = setting << x
  end
  
end
