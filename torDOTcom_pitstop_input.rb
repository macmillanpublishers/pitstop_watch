require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

project_dir = data_hash['project']
stage_dir = data_hash['stage']

if File.file?("#{Bkmkr::Paths.resource_dir}/staging.txt")
	staging = "_staging"
else
	staging = ""
end

this_pitstop_dir = File.join("P:", "#{project_dir}_POD#{staging}", "input")

if File.file?(this_pitstop_dir)
	pitstop_dir = this_pitstop_dir
else
	pitstop_dir = File.join("P:", "torDOTcom_POD#{staging}", "input")
end
input_filename = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "#{Metadata.pisbn}_POD.pdf")
pitstop_filename = File.join(pitstop_dir, "#{project_dir}_#{stage_dir}-#{Metadata.pisbn}.pdf")

FileUtils.mv(input_filename, pitstop_filename)

# LOGGING

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
	f.puts "----- SENT PDF TO PITSTOP"
end