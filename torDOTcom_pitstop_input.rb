require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

if File.file?("#{Bkmkr::Paths.resource_dir}/staging.txt")
	pitstop_dir = File.join("P:", "torDOTcom_POD_staging", "input")
else
	pitstop_dir = File.join("P:", "torDOTcom_POD", "input")
end
input_filename = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "#{Metadata.pisbn}_POD.pdf")
pitstop_filename = File.join(pitstop_dir, "#{Bkmkr::Project.project_dir}_#{Bkmkr::Project.stage_dir}-#{Metadata.pisbn}.pdf")

FileUtils.mv(input_filename, pitstop_filename)