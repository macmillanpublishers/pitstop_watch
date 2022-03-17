require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

json_log = Bkmkr::Paths.json_log
testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")
pitstop_cfg_json = File.join(Bkmkr::Paths.scripts_dir, "pitstop_watch", "pitstop_cfg.json")
input_filename = File.join(Metadata.final_dir, "#{Metadata.pisbn}_POD.pdf")

# ---------------------- METHODS
def readJson(jsonfile, logkey='')
  data_hash = Mcmlln::Tools.readjson(jsonfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def checkStaging(staging_file, prod_pitstop_drive, stg_pitstop_drive, logkey='')
  if File.file?(staging_file)
    ps_drive_letter = "#{stg_pitstop_drive}:"
    staging = "_staging"
  else
    ps_drive_letter = "#{prod_pitstop_drive}:"
    staging = ""
  end
  return ps_drive_letter, staging
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getPitstopFilepath(json_log_hash, pitstop_maindir_backup, default_dir_prefix_backup, staging, logkey='')
  pitstop_maindir = pitstop_maindir_backup
  pitstop_filename = default_dir_prefix_backup
  json_values_used = false
  if json_log_hash.has_key?("torDOTcom_pitstop_input.rb")
    if json_log_hash["torDOTcom_pitstop_input.rb"].has_key?("pitstop_maindir") && json_log_hash["torDOTcom_pitstop_input.rb"].has_key?("pitstop_filename")
      pitstop_maindir = json_log_hash["torDOTcom_pitstop_input.rb"]["pitstop_maindir"]
      pitstop_filename = json_log_hash["torDOTcom_pitstop_input.rb"]["pitstop_filename"]
      json_values_used = true
    end
  end
  pitstop_full_filepath = File.join(pitstop_maindir, 'done', pitstop_filename)
  ### leaving this commented commented conditional with 'staging' value,
  ###   in case, during course of pitstop development, one env becomes unusable:
  ###   we can simply uncomment to have both bkmkr servers share one pitstop server again.
  # if staging != ""
  #   pitstop_full_filepath = File.join("#{pitstop_maindir}_staging", 'done', pitstop_filename)
  # end
  if json_values_used == false
    logstring = "unable to find or parse jsonlog for pitstop_input values, using default"
  end
  return pitstop_full_filepath
rescue => logstring
  # revert to backup values
  return File.join(pitstop_maindir_backup, 'done', default_dir_prefix_backup)
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
def copyProcessedFile(pitstop_full_filepath, input_filename, pitstop_error, logkey='')
  if File.file?(pitstop_full_filepath)
    FileUtils.cp(pitstop_full_filepath, input_filename)
    logstring = 'copied processed file (<= 30 seconds wait )'
  else
    sleep(60)
    if File.file?(pitstop_full_filepath)
      FileUtils.cp(pitstop_full_filepath, input_filename)
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
data_hash = readJson(Metadata.configfile, 'read_config_json')
json_log_hash = readJson(json_log, 'read_json_log')
pitstop_cfg_hash = readJson(pitstop_cfg_json, 'read_pitstop_cfg_json')

##### local definition(s) based on data from config.json
project_dir = data_hash['project']
stage_dir = data_hash['stage']
default_dir_prefix = pitstop_cfg_hash['default']
prod_pitstop_drive = pitstop_cfg_hash['prod_pitstop_drive']
stg_pitstop_drive = pitstop_cfg_hash['stg_pitstop_drive']

# getting this info in case pitstop_input log values are unusable, so we have a default value as backup
ps_drive_letter, staging = checkStaging(testing_value_file, prod_pitstop_drive, stg_pitstop_drive, 'get_prd-or-stg_driveletter')

# set defaults in case jsonlog values not avail in the upcoming function...
pitstop_maindir = File.join(ps_drive_letter, "#{default_dir_prefix}_POD")
pitstop_filename = File.join("#{project_dir}_#{stage_dir}-#{Metadata.pisbn}.pdf")
pitstop_full_filepath = getPitstopFilepath(json_log_hash, pitstop_maindir, pitstop_filename, staging, 'get_pitstop_filepath')
@log_hash['pitstop_full_filepath'] = pitstop_full_filepath

# rm existing pitstrop_errfile if exists (from prior run(s))
pitstop_error = File.join(Metadata.final_dir, "PITSTOP_ERROR.txt")
rmFile(pitstop_error, 'rm_pitstop_error_file')

sleep(30)

# copy completed file back to done_dir, or write ERROR file
copyProcessedFile(pitstop_full_filepath, input_filename, pitstop_error, 'copy_processed_file_back_to_done_dir')

# delete processed file from pitstrop folder
rmFile(pitstop_full_filepath, 'rm_file_from_pitstop_folder')

# ---------------------- LOGGING

#test for pitstop errfile for old logging framework
testErrFile(pitstop_error, 'test_for_pitstop_err_file')

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
