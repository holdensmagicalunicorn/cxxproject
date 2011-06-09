require 'cxxproject/errorparser/error_parser'

class DiabLinkerErrorParser < ErrorParser

  def getSeverity(str)
    if str == "info"
      0
    elsif str == "warning"
      1
    elsif str == "error" or str == "catastrophic error"
      2
    else
      raise "Unknown severity: #{str}"
    end
  end

  def scan(consoleOutput, proj_dir)
    res = []
    consoleOutput.scan(/dld: ([A-Za-z]+): (.+)/).each do |e|
      res << [
        proj_dir,
        0,
        getSeverity(e[0]),
        e[1] ]
      end
    res
  end

end