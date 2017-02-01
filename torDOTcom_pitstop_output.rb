require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")


# ---------------------- METHODS
def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def checkStaging(file, logkey='')
  if File.file?(file)
    staging = "_staging"
  else
    staging = ""
  end
  return staging
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setPitstopDir(this_pitstop_dir, staging, logkey='')
  if File.exist?(this_pitstop_dir)
    pitstop_dir = this_pitstop_dir
  else
    pitstop_dir = File.join("P:", "SMP_POD#{staging}", "input")
  end
  return pitstop_dir
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def rmFile(file, logkey='')
  if File.file?(file)
    Mcmlln::Tools.deleteFile(file)
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeErrorFile(pitstop_error, logkey='')
  File.open(pitstop_error, 'w') do |output|
    output.write "Pitstop could not process your final PDF. Please email workflows@macmillan.com for assistance."
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# copy completed file back to done_dir, or write ERROR file
def copyProcessedFile(pitstop_filename, input_filename, pitstop_error, logkey='')
  if File.file?(pitstop_filename)
    FileUtils.cp(pitstop_filename, input_filename)
    logstring = 'copied processed file (<= 30 seconds wait )'
  else
    sleep(60)
    if File.file?(pitstop_filename)
      FileUtils.cp(pitstop_filename, input_filename)
      logstring = 'copied processed file (30-90 second wait)'
    else
      writeErrorFile(pitstop_error, 'write_pitstop_err_file')
      logstring = 'no processed file in 90 seconds, wrote errfile'
    end
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def testErrFile(pitstop_error, logkey='')
  # see if pitstop failed
  if File.file?(pitstop_error)
    test_pitstop_status = "----- pitstop FAILED"
  else
    test_pitstop_status = "----- pitstop finished successfully"
  end
  return test_pitstop_status
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES
data_hash = readConfigJson('read_config_json')

##### local definition(s) based on data from config.json
project_dir = data_hash['project']
stage_dir = data_hash['stage']

# see if we're on the staging server
staging = checkStaging(testing_value_file, 'check_if_on_staging')
@log_hash['staging_value'] = staging

this_pitstop_dir = File.join("P:", "#{project_dir}_POD#{staging}", "done")

# choose pitstop_dir by project, if folder doesn't exist for this project default to SMP_POD
pitstop_dir = setPitstopDir(this_pitstop_dir, staging, 'set_pitstop_dir')

input_filename = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "#{Metadata.pisbn}_POD.pdf")
pitstop_filename = File.join(pitstop_dir, "#{project_dir}_#{stage_dir}-#{Metadata.pisbn}.pdf")
pitstop_error = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "PITSTOP_ERROR.txt")

# rm existing pitstrop_errfile if exists (from prior run(s))
rmFile(pitstop_error, 'rm_pitstop_error_file')

sleep(30)

# copy completed file back to done_dir, or write ERROR file
copyProcessedFile(pitstop_filename, input_filename, pitstop_error, 'copy_processed_file_back_to_done_dir')

# delete processed file from pitstrop folder
rmFile(pitstop_filename, 'rm_file_from_pitstop_folder')

# ---------------------- LOGGING

#test for pitstop errfile for old logging framework
test_pitstop_status = testErrFile(pitstop_error, 'test_for_pitstop_err_file')

# wrapping this legacy log in a begin block so it doesn't hose travis tests.
begin
  # Printing the test results to the log file
  File.open(Bkmkr::Paths.log_file, 'a+') do |f|
    f.puts "----- PITSTOP PROCESSING COMPLETE"
    f.puts test_pitstop_status
  end
rescue => e
  puts '(Ignore for unit-tests:) ERROR encountered in process block: ', e
end

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)

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
