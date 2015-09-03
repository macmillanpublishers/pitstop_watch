require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

if File.file?("#{Bkmkr::Paths.resource_dir}/staging.txt")
	pitstop_dir = File.join("P:", "#{project_dir}_POD_staging", "input")
else
	pitstop_dir = File.join("P:", "#{project_dir}_POD", "input")
end

input_filename = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "#{Metadata.pisbn}_POD.pdf")
pitstop_filename = File.join(pitstop_dir, "#{project_dir}_#{stage_dir}-#{Metadata.pisbn}.pdf")
pitstop_error = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "PITSTOP_ERROR.txt")

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

FileUtils.rm(Bkmkr::Paths.alert)
FileUtils.rm(input_file)

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

