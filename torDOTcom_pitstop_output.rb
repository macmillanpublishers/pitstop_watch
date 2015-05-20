require 'fileutils'

input_file = ARGV[0]
input_file = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).join(File::SEPARATOR)
filename = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.split("-").pop
isbn = filename.split("_").shift
project_dir = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.split("-").shift
final_dir = File.join("S:", "bookmaker", project_dir, "done", "#{isbn}", "#{filename}")
alert = File.join("S:", "bookmaker", project_dir, "IN_USE_PLEASE_WAIT.txt")

FileUtils.mv(input_file, final_dir)
FileUtils.rm(alert)