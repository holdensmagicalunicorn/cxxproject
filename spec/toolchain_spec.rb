require 'cxxproject/toolchain/toolchain'

describe String do
  it 'should correctly load toolchain from json file' do
    tc = Toolchain.new('../lib/cxxproject/toolchain/gcc.json')
    tc.name.should == "gcc"
    tc.compiler.cpp.command.should == "g++"
    tc.compiler.c.source_file_endings.should == [".c"]
    tc.linker.output_ending == ".exe"
  end

  it 'should be possible to add list items to existing settings' do
    tc = Toolchain.new('../lib/cxxproject/toolchain/gcc.json')
    tc.compiler.c.source_file_endings.should == [".c"]
    tc.add_to_list(['compiler','c','source_file_endings'], ".cc")
    tc.compiler.c.source_file_endings.should == [".c",".cc"]
  end

end
