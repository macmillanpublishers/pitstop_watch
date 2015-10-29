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

this_pitstop_dir = File.join("P:", "#{project_dir}_POD#{staging}", "done")

if File.exist?(this_pitstop_dir)
	pitstop_dir = this_pitstop_dir
else
	pitstop_dir = File.join("P:", "SMP_POD#{staging}", "done")
end

input_filename = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "#{Metadata.pisbn}_POD.pdf")
pitstop_filename = File.join(pitstop_dir, "#{project_dir}_#{stage_dir}-#{Metadata.pisbn}.pdf")
pitstop_error = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "PITSTOP_ERROR.txt")

if File.file?(pitstop_error)
	FileUtils.rm(pitstop_error)
end

sleep(30)

if File.file?(pitstop_filename)
	FileUtils.cp(pitstop_filename, input_filename)
else
	sleep(60)
	if File.file?(pitstop_filename)
		FileUtils.cp(pitstop_filename, input_filename)
	else
		File.open(pitstop_error, 'w') do |output|
			output.write "Pitstop could not process your final PDF. Please email workflows@macmillan.com for assistance."
		end
	end
end

FileUtils.rm(pitstop_filename)

# LOGGING

# see if pitstop failed
if File.file?(pitstop_error)
	test_pitstop_status = "----- pitstop FAILED"
else
	test_pitstop_status = "----- pitstop finished successfully"
end

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
	f.puts "----- PITSTOP PROCESSING COMPLETE"
	f.puts test_pitstop_status
end

# old script
# unescapeargv = ARGV[0].chomp('"').reverse.chomp('"').reverse
# input_file = File.expand_path(unescapeargv)
# input_file = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).join(File::SEPARATOR)
# filename = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.split("-").pop
# isbn = filename.split(".").shift
# project_dir = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.split("-").shift
# final_dir = File.join("S:", "bookmaker", project_dir, "done", "#{isbn}", "#{isbn}_POD.pdf")
# alert = File.join("S:", "bookmaker", project_dir, "IN_USE_PLEASE_WAIT.txt")

# FileUtils.cp(input_file, final_dir)
# FileUtils.rm(alert)
# FileUtils.rm(input_file)

