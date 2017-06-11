require 'fileutils'
require 'tmpdir'

class Slightish::Sandbox
  attr_reader :path

  def initialize(template_dir: nil, prefix: 'slightish')
    @path = Dir.mktmpdir(prefix)

    # The '.' prevents cp_r from making a new directory at the destination --
    # kind of the equivalent of '/*' in bash.
    FileUtils.cp_r(File.join(template_dir, '.'), @path) unless template_dir.nil?
  end

  def delete
    FileUtils.remove_entry_secure(@path)
  end
end
