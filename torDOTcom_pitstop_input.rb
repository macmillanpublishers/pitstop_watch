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
staging = checkStaging(testing_value_file, 'check_if_on_staging')
@log_hash['staging_value'] = staging

# set pitstop dir, including staging as needed
this_pitstop_dir = File.join("P:", "#{project_dir}_POD#{staging}", "input")

# choose pitstop_dir by project, if folder doesn't exist for this project default to SMP_POD
pitstop_dir = setPitstopDir(this_pitstop_dir, staging, 'set_pitstop_dir')

input_filename = File.join(Metadata.final_dir, "#{Metadata.pisbn}_POD.pdf")
pitstop_filename = File.join(pitstop_dir, "#{project_dir}_#{stage_dir}-#{Metadata.pisbn}.pdf")
@log_hash['pitstop_filename'] = pitstop_filename

moveFileToPitstopDir(input_filename, pitstop_filename, 'move_file_to_pitstop_dir')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
