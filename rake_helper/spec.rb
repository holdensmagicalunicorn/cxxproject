SPEC_PATTERN ='spec/**/*_spec.rb'
require './lib/cxxproject/utils/optional'
def rcov_for_18
  use_rcov = true
  begin
    gem "rcov"
  rescue LoadError
    warn "rcov not installed...code coverage will not be measured!"
    use_rcov = false
  end
  use_rcov
end


def coverage
  load_rcov = lambda do
    require 'rcov'
    RSpec::Core::RakeTask.new(:coverage) do |t|
      t.pattern = SPEC_PATTERN
      t.rcov = true
      t.rcov_opts = ['--exclude', '.*/gems/.*']
    end
  end
  simple_cov_or_nothing = lambda do
    load_simplecov = lambda do
      require 'simplecov'
      task :coverage do
        ENV['COVERAGE'] = 'yes'
        Rake::Task['spec:spec'].invoke
      end
    end
    could_not_define_rcov_or_simplecov = lambda do
      task :coverage do
        puts "Please install coverage tools with\n\"gem install simplecov\" for ruby 1.9 or\n\"gem install rcov\" for ruby 1.8"
      end
    end
    Cxxproject::Utils::optional_package(load_simplecov, could_not_define_rcov_or_simplecov)
  end
  Cxxproject::Utils::optional_package(load_rcov, simple_cov_or_nothing)
end

def new_rspec
  require 'rspec/core/rake_task'
  desc "Run examples"
  RSpec::Core::RakeTask.new() do |t|
    t.pattern = SPEC_PATTERN
  end

  desc 'Run examples with coverage'
  coverage
  CLOBBER.include('coverage')
end

def old_rspec
  require 'spec/rake/spectask'
  desc "Run examples"
  Spec::Rake::SpecTask.new() do |t|
    t.spec_files = SPEC_PATTERN
  end
end

namespace :spec do
  begin
    new_rspec
  rescue LoadError
    begin
      old_rspec
    rescue LoadError
      desc "Run examples"
      task 'spec' do
        puts 'rspec not installed...! please install with "gem install rspec"'
      end
    end
  end
end
task :spec do
  puts 'Please use spec:spec or spec:coverage'
end
task :gem => [:spec]

