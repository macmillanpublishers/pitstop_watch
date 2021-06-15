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
  this_pitstop_dir = File.join(ps_drive_letter, "#{project_dir}_POD", "input")
  # this_pitstop_dir = File.join(ps_drive_letter, "#{project_dir}_POD#{staging}", "done")
  ### leaving this commented, alternate value ^^^ including 'staging' value,
  ###   in case, during course of pitstop development, one env becomes unusable:
  ###   we can simply uncomment to have both bkmkr servers share one pitstop server again.
  ### (ditto line 53 below)

  # fallback on smp if no folder for this project_dir
  if File.exist?(this_pitstop_dir)
    pitstop_dir = this_pitstop_dir
  else
    pitstop_dir = File.join(ps_drive_letter, "SMP_POD", "input")
    # pitstop_dir = File.join(ps_drive_letter, "SMP_POD#{staging}", "input")
  end
  return pitstop_dir
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def moveFileToPitstopDir(file, dest, logkey='')
  Mcmlln::Tools.moveFile(file, dest)
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

moveFileToPitstopDir(input_filename, pitstop_filename, 'move_file_to_pitstop_dir')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
