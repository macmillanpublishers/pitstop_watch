require 'fileutils'

require_relative '../bookmaker/header.rb'
require_relative '../bookmaker/metadata.rb'

input_filename = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "#{Metadata.pisbn}_POD.pdf")
pitstop_dir = File.join("P:", "torDOTcom_POD", "input")
pitstop_filename = File.join(pitstop_dir, "#{Bkmkr::Project.project_dir}_#{Bkmkr::Project.stage_dir}-#{pisbn}.pdf")

FileUtils.mv(input_filename, pitstop_filename)