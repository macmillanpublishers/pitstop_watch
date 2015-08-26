require 'fileutils'

unescapeargv = ARGV[0].chomp('"').reverse.chomp('"').reverse
input_file = File.expand_path(unescapeargv)
input_file = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).join(File::SEPARATOR)
filename = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.split("-").pop
isbn = filename.split(".").shift
project_dir = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.split("-").shift
final_dir = File.join("S:", "bookmaker", project_dir, "done", "#{isbn}", "#{isbn}_POD.pdf")
alert = File.join("S:", "bookmaker", project_dir, "IN_USE_PLEASE_WAIT.txt")

FileUtils.cp(input_file, final_dir)
FileUtils.rm(alert)
FileUtils.rm(input_file)