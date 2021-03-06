require 'cxxproject/buildingblocks/has_dependencies_mixin'
require 'cxxproject/utils/exit_helper'
require 'cxxproject/attribute_helper'
require 'cxxproject/ext/rake'
require 'cxxproject/ext/file'
require 'cxxproject/ide_interface'
require 'cxxproject/utils/printer'

# no deprecated warning for rake >= 0.9.x
include Rake::DSL if defined?(Rake::DSL)
module Cxxproject

  # stores all defined buildingblocks by name (the name should be unique)
  ALL_BUILDING_BLOCKS = {}

  trap("INT") do
    Rake.application.idei.set_abort(true)
  end

  class BuildingBlock
    include HasDependencies

    attr_reader :name
    attr_reader :config_files

    attr_reader :project_dir
    attr_accessor :output_dir
    attr_reader :output_dir_abs

    def set_name(x)
      @name = x
      self
    end

    def set_tcs(x)
      @tcs = x
      self
    end

    def has_tcs?
      @tcs != nil
    end

    def tcs()
      raise "Toolchain settings must be set before!" if @tcs.nil?
      @tcs
    end

    def set_config_files(x)
      @config_files = x
      self
    end

    def set_project_dir(x)
      @project_dir = File.expand_path(x)
      if @output_dir_abs
        @output_dir_relPath = File.rel_from_to_project(@project_dir, @output_dir)
      end
      self
    end

    # if output dir is absolute, -L and -l is used for linker ("linux mode")
    def set_output_dir(x)
      return self if @output_dir

      @output_dir = x
      @output_dir_abs = File.is_absolute?(@output_dir)
      if @project_dir
        @output_dir_relPath = File.rel_from_to_project(@project_dir, @output_dir)
      end
      self
    end

    def complete_output_dir
      @complete_output_dir ||= calc_complete_output_dir
    end

    def calc_complete_output_dir
      if @output_dir_abs
        @output_dir
      else
        File.join(@project_dir,  @output_dir)
      end
    end

    def initialize(name)
      @name = name
      @config_files = []
      @project_dir = nil
      @tcs = nil
      @output_dir = nil
      @output_dir_abs = false
      @complete_output_dir = nil

      if ALL_BUILDING_BLOCKS.include?(@name) and not self.instance_of?(BinaryLibrary)
        raise "building block already exists: #{name}"
      else
        ALL_BUILDING_BLOCKS[@name] = self
      end
    end

    def complete_init()
      if self.respond_to?(:calc_compiler_strings)
        calc_compiler_strings
      end
    end

    def get_task_name()
      raise "this method must be implemented by decendants"
    end

    ##
    # convert all dependencies of a building block to rake task prerequisites (e.g. exe needs lib)
    #
    def setup_rake_dependencies(task)
      dependencies.reverse_each do |d|
        begin
          bb = ALL_BUILDING_BLOCKS[d]
          raise "Error: tried to add the dependencies of \"#{d}\" to \"#{@name}\" but such a building block could not be found!" unless bb
          task.prerequisites.unshift(bb.get_task_name)
        rescue ExitHelperException
          raise
        rescue Exception => e
          Printer.printError e
          ExitHelper.exit(1)
        end
      end
      task
    end

    def add_output_dir_dependency(file, taskOfFile, addDirToCleanTask)
      d = File.dirname(file)
      directory d
      taskOfFile.enhance([d])
      
      if addDirToCleanTask
        if (@output_dir_abs)
          CLEAN.include(file)
        else
          CLEAN.include(complete_output_dir)
        end
      end
    end

    def process_result(cmd, console_output, error_parser = nil, alternate = nil)

      hasError = ($?.success? == false)
 
      if hasError or RakeFileUtils.verbose or (alternate.nil? and not Rake::application.options.silent)
        exedIn = ""
        exedIn = " (executed in '#{Dir.pwd}')" if (hasError or RakeFileUtils.verbose)
        if cmd.is_a?(Array)
          puts cmd.join(' ') + exedIn
        else
          puts cmd + exedIn
        end
      else
        puts alternate unless Rake::application.options.silent
      end

      process_console_output(console_output, error_parser)
      
      if hasError
        Printer.printError "Error: system command failed"
        raise SystemCommandFailed.new
      end
    end

    def read_file_or_empty_string(filename)
      begin
        return File.read(filename)
      rescue
        return ""
      end
    end

    def typed_file_task(type, *args, &block)
      t = file *args do
        block.call
      end
      t.type = type
      t.progress_count = 1
      return t
    end

    def remove_empty_strings_and_join(a, j=' ')
      return a.reject{|e|e.to_s.empty?}.join(j)
    end

    def catch_output(cmd)
      new_command = "#{cmd} 2>&1"
      return `#{new_command}`
    end

  end
  
end
