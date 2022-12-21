require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")
pitstop_api_cfg_json = File.join(Bkmkr::Paths.scripts_dir, "pitstop_watch", "pitstop_api_cfg.json")
pitstop_imprint_defaults_json = File.join(Bkmkr::Paths.scripts_dir, "pitstop_watch", "pitstop_imprint_defaults.json")
input_filename = File.join(Metadata.final_dir, "#{Metadata.pisbn}_POD.pdf")
api_POST_to_flask_py = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_connectors", "api_POST_to_flask.py")
job_id = File.basename(Bkmkr::Paths.project_tmp_dir)
pitstop_inprogress = File.join(Bkmkr::Paths.project_tmp_dir, "SENT_TO_PITSTOP.txt")
pitstop_error = File.join(Metadata.final_dir, "PITSTOP_ERROR.txt")
pitstop_err_str = "Pitstop could not process your final PDF. Please email workflows@macmillan.com for assistance."

# ---------------------- METHODS
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

def readJson(jsonfile, logkey='')
  data_hash = Mcmlln::Tools.readjson(jsonfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# determine ps setting:
#   1) if pitstop processing instruction, set to that value
#   2) if imprint defaults has a default for this imprint, use that
#   3) use project_dir prefix.
# if corresponding setting is not present in PS for ps_Setting, we will have pitstop_exec set to revert to a default
def getPitstopSetting(project_dir, pi_pitstop_dir, imprint, pitstop_imprint_defaults_hash, logkey='')
  default = pitstop_imprint_defaults_hash['default']
  imprint_defaults = pitstop_imprint_defaults_hash['imprint_defaults']
  ps_settings = pitstop_imprint_defaults_hash['available_ps_settings']

  if pi_pitstop_dir != ""
    pitstop_setting = pi_pitstop_dir
  elsif imprint_defaults.has_key?(imprint)
    pitstop_setting = imprint_defaults[imprint]
  elsif ps_settings.include? project_dir
    pitstop_setting = project_dir
  else
    pitstop_setting = default
  end

  # add bookmaker prefix
  pitstop_setting = "bookmaker_#{pitstop_setting}"

  return pitstop_setting
rescue => logstring
  return default
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.runpython in a new method for this script; to return a result for json_logfile
def localRunPython(py_script, args, logkey='')
	result = Bkmkr::Tools.runpython(py_script, args).strip()
  logstring = "result_string: #{result}"
  return result
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# this function identical to one in validator_cleanup_direct; except for .py invocation line
def sendFileToPSserver(file_to_send, api_POST_to_flask_py, post_url, uname, pw, ps_setting_keyname, ps_setting, job_id, callback_url, logkey='')
  #loop through files to upload:
  argstring = "#{file_to_send} #{post_url} #{uname} #{pw} #{ps_setting_keyname} #{ps_setting} job_id #{job_id} callback_url #{callback_url}"
  logstring = "api args: #{argstring}"
  api_result = localRunPython(api_POST_to_flask_py, argstring, "run_py__api_POST_to_flask")
  return api_result
rescue => e
  p e
  logstring += "\n - error with 'sendFileToPSserver': #{e}"
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeTextFile(pitstop_error, string, logkey='')
  File.open(pitstop_error, 'w') do |output|
    output.write string
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- PROCESSES
# rm existing pitstop_errfile if exists (from prior run(s))
rmFile(pitstop_error, 'rm_pitstop_error_file')

cfg_hash = readJson(Metadata.configfile, 'read_config_json')
pitstop_imprint_defaults_hash = readJson(pitstop_imprint_defaults_json, 'read_pitstop_imprint_defaults_json')
pitstop_api_cfg_hash = readJson(pitstop_api_cfg_json, 'read_pitstop_api_cfg_json')

##### local definition(s) based on data from config.jsons
project_dir = cfg_hash['project']
imprint = cfg_hash['resourcedir']
if cfg_hash.has_key?('pitstop_dir')
  pi_pitstop_dir = cfg_hash['pitstop_dir']
else
  pi_pitstop_dir = ''
end

callback_url = pitstop_api_cfg_hash['callback_api_url']
ps_setting_keyname = pitstop_api_cfg_hash['ps_setting_keyname']
# set url per prod/stg environment
if File.file?(testing_value_file)
  pitstop_url = pitstop_api_cfg_hash['to_pitstop_url_stg']
  # environment = 'staging'
  uname = pitstop_api_cfg_hash['to_pitstop_credentials_stg']['uname']
  pw = pitstop_api_cfg_hash['to_pitstop_credentials_stg']['pw']
else
  pitstop_url = pitstop_api_cfg_hash['to_pitstop_url_prod']
  # environment = 'prod'
  uname = pitstop_api_cfg_hash['to_pitstop_credentials_prod']['uname']
  pw = pitstop_api_cfg_hash['to_pitstop_credentials_prod']['pw']
end
@log_hash['pitstop_url'] = pitstop_url

# determine pitstop setting value to pass to api
ps_setting = getPitstopSetting(project_dir, pi_pitstop_dir, imprint, pitstop_imprint_defaults_hash, 'get_pitstop_setting')
@log_hash['ps_setting'] = ps_setting

# send file
api_POST_results = sendFileToPSserver(input_filename, api_POST_to_flask_py, pitstop_url, uname, pw, ps_setting_keyname, ps_setting, job_id, callback_url, 'send_pdf_to_pitstop_api')
@log_hash['api_POST_results'] = api_POST_results

# write err on send err
if api_POST_results.downcase.strip() == 'success'
  writeTextFile(pitstop_inprogress, "pitstop in progress",'write_pitstop_in_progress_file')
else
  writeTextFile(pitstop_error, pitstop_err_str, 'write_pitstop_err_file')
end

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
