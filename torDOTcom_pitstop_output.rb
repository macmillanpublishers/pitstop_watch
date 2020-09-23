require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")

prod_pitstop_drive = "Q:"
stg_pitstop_drive = "P:"

# ---------------------- METHODS
def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def checkStaging(staging_file, prod_pitstop_drive, stg_pitstop_drive, logkey='')
  if File.file?(staging_file)
    ps_drive_letter = stg_pitstop_drive
    staging = "_staging"
  else
    ps_drive_letter = prod_pitstop_drive
    staging = ""
  end
  return ps_drive_letter, staging
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setPitstopDir(project_dir, ps_drive_letter, staging, logkey='')
  # set pitstop dir
  this_pitstop_dir = File.join(ps_drive_letter, "#{project_dir}_POD", "done")
  # this_pitstop_dir = File.join(ps_drive_letter, "#{project_dir}_POD#{staging}", "done")
  ### leaving this commented, alternate value ^^^ including 'staging' value,
  ###   in case, during course of pitstop development, one env becomes unusable:
  ###   we can simply uncomment to have both bkmkr servers share one pitstop server again.
  ### (ditto line 53 below)

  # fallback on smp if no folder for this project_dir
  if File.exist?(this_pitstop_dir)
    pitstop_dir = this_pitstop_dir
  else
    pitstop_dir = File.join(ps_drive_letter, "SMP_POD", "done")
    # pitstop_dir = File.join(ps_drive_letter, "SMP_POD#{staging}", "done")
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
    logstring = "----- pitstop FAILED"
  else
    logstring = "----- pitstop finished successfully"
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES
data_hash = readConfigJson('read_config_json')

##### local definition(s) based on data from config.json
project_dir = data_hash['project']
stage_dir = data_hash['stage']

# see if we're on the staging server
ps_drive_letter, staging = checkStaging(testing_value_file, prod_pitstop_drive, stg_pitstop_drive, 'get_prd-or-stg_driveletter')
@log_hash['ps_drive_letter'] = ps_drive_letter
@log_hash['staging'] = staging

# choose pitstop_dir by project, if folder doesn't exist for this project default to SMP_POD
pitstop_dir = setPitstopDir(project_dir, ps_drive_letter, staging, 'set_pitstop_dir')

input_filename = File.join(Metadata.final_dir, "#{Metadata.pisbn}_POD.pdf")
pitstop_filename = File.join(pitstop_dir, "#{project_dir}_#{stage_dir}-#{Metadata.pisbn}.pdf")
@log_hash['pitstop_filename'] = pitstop_filename

# rm existing pitstrop_errfile if exists (from prior run(s))
pitstop_error = File.join(Metadata.final_dir, "PITSTOP_ERROR.txt")
rmFile(pitstop_error, 'rm_pitstop_error_file')

sleep(30)

# copy completed file back to done_dir, or write ERROR file
copyProcessedFile(pitstop_filename, input_filename, pitstop_error, 'copy_processed_file_back_to_done_dir')

# delete processed file from pitstrop folder
rmFile(pitstop_filename, 'rm_file_from_pitstop_folder')

# ---------------------- LOGGING

#test for pitstop errfile for old logging framework
testErrFile(pitstop_error, 'test_for_pitstop_err_file')

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
