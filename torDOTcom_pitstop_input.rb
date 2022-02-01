require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")
pitstop_cfg_json = File.join(Bkmkr::Paths.scripts_dir, "pitstop_watch", "pitstop_cfg.json")

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

def setPitstopDir(project_dir, pi_pitstop_dir, imprint, default, imprint_defaults, ps_drive_letter, staging, logkey='')
  # set generic default for backup / rescue
  backup_pitstop_dir = File.join(ps_drive_letter, "#{default}_POD")

  if pi_pitstop_dir
    ps_folder_prefix = pi_pitstop_dir
  elsif imprint_defaults.has_key?(imprint)
    ps_folder_prefix = imprint_defaults[imprint]
  else
    # this value correponds to bookmaker IN folder, values will be 'bookmaker' or 'tordotcom'
    ps_folder_prefix = project_dir
  end

  # set pitstop dir
  this_pitstop_dir = File.join(ps_drive_letter, "#{ps_folder_prefix}_POD")

  # fallback on smp if specified folder does not exist
  if File.exist?(this_pitstop_dir)
    pitstop_dir = this_pitstop_dir
  else
    pitstop_dir = backup_pitstop_dir
    logstring = "pitstop dir: \"#{this_pitstop_dir}\" does not exist, falling back to \"#{pitstop_dir}\""
  end

  ### leaving this commented commented conditional with 'staging' value,
  ###   in case, during course of pitstop development, one env becomes unusable:
  ###   we can simply uncomment to have both bkmkr servers share one pitstop server again.
  # if staging != ""
  #   pitstop_dir = File.join("#{File.dirname(pitstop_dir)}_staging", 'input')
  # end

  return pitstop_dir
rescue => logstring
  return backup_pitstop_dir
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
cfg_hash = readJson(Metadata.configfile, 'read_config_json')
pitstop_cfg_hash = readJson(pitstop_cfg_json, 'read_pitstop_cfg_json')

##### local definition(s) based on data from config.jsons
project_dir = cfg_hash['project']
stage_dir = cfg_hash['stage']
imprint = cfg_hash['stage']
if cfg_hash.has_key?('pitstop_dir') then pi_pitstop_dir = cfg_hash['pitstop_dir'] else pi_pitstop_dir = '' end
prod_pitstop_drive = pitstop_cfg_hash['prod_pitstop_drive']
stg_pitstop_drive = pitstop_cfg_hash['stg_pitstop_drive']
default = pitstop_cfg_hash['default']
imprint_defaults = pitstop_cfg_hash['imprint_defaults']

# see if we're on the staging server
ps_drive_letter, staging = checkStaging(testing_value_file, prod_pitstop_drive, stg_pitstop_drive, 'get_prd-or-stg_driveletter')
@log_hash['ps_drive_letter'] = ps_drive_letter
@log_hash['staging'] = staging

# choose pitstop_dir by project, if folder doesn't exist for this project default to SMP_POD
pitstop_maindir = setPitstopDir(project_dir, pi_pitstop_dir, imprint, default, imprint_defaults, ps_drive_letter, staging, 'set_pitstop_dir')
pitstop_dir = File.join(pitstop_maindir, "input")
@log_hash['pitstop_maindir'] = pitstop_maindir

pitstop_filename = File.join("#{project_dir}_#{stage_dir}-#{Metadata.pisbn}.pdf")
pitstop_full_filepath = File.join(pitstop_dir, pitstop_filename)
@log_hash['pitstop_filename'] = pitstop_filename
@log_hash['pitstop_full_filepath'] = pitstop_full_filepath

input_filename = File.join(Metadata.final_dir, "#{Metadata.pisbn}_POD.pdf")

moveFileToPitstopDir(input_filename, pitstop_filename, 'move_file_to_pitstop_dir')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
