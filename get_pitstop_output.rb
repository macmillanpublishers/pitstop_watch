require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

json_log = Bkmkr::Paths.json_log
pitstop_api_cfg_json = File.join(Bkmkr::Paths.scripts_dir, "pitstop_watch", "pitstop_api_cfg.json")
final_pdf_filename = File.join(Metadata.final_dir, "#{Metadata.pisbn}_POD.pdf")
pitstop_inprogress = File.join(Bkmkr::Paths.project_tmp_dir, "SENT_TO_PITSTOP.txt")
pitstop_error = File.join(Metadata.final_dir, "PITSTOP_ERROR.txt")

# ---------------------- METHODS
def readJSON(jsonfile, logkey='')
  data_hash = Mcmlln::Tools.readjson(jsonfile)
  return data_hash
rescue => logstring
  return {}
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

def getPitstopStatus(ps_json, ps_pdf, check_count, seconds_per_check, pitstop_inprogress, logkey='')
  ps_result = ''
  ps_status = ''
  json_found = false
  i = 0
  while !File.file?(ps_json) && i < check_count do
    sleep(seconds_per_check)
    i+=1
  end
  if File.file?(ps_json)
    # ps process done, rm inprogress file
    rmFile(pitstop_inprogress, 'rm_psinprogress_file_from_tmpdir')
    # get ps_status data
    ps_status_hash = readJSON(ps_json, 'read_ps_status_json')
    if ps_status_hash.has_key?('pitstop_status')
      ps_status = ps_status_hash['pitstop_status']
    end
    # setup logstring and results
    if File.file?(ps_pdf)
      logstring = "both from_pitstop files found (#{i*seconds_per_check} second wait)"
      ps_result = ps_status
    else
      logstring = "ps_json present, ps_pdf missing (#{i*seconds_per_check} second wait)"
      ps_result = "ps_pdf missing, ps_status: #{ps_status}"
    end
  else
    logstring = "waited #{i*seconds_per_check} seconds, no pitstop_status json"
    ps_result = "no pitstop_status json"
  end

  return ps_result
rescue => logstring
  return ps_result
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# copy completed file back to done_dir
def copyProcessedFile(pitstop_full_filepath, input_filename, logkey='')
  FileUtils.cp(pitstop_full_filepath, input_filename)
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


# ---------------------- PROCESSES
# if pitstop errfile already present, skip this script!
if File.file?(pitstop_error)
  @log_hash['script_early_exit'] = "pitstop_Errfile already present, file was not sent to pitstop, skipping to the end"
else
  pitstop_api_cfg_hash = readJSON(pitstop_api_cfg_json, 'read_pitstop_api_cfg_json')
  api_uploads_tmpdir = pitstop_api_cfg_hash['from_pitstop_uploads_dir']['path']
  upload_job_id = File.basename(Bkmkr::Paths.project_tmp_dir)
  ps_pdf = File.join(api_uploads_tmpdir, upload_job_id, "#{Metadata.pisbn}_POD.pdf")
  ps_json = File.join(api_uploads_tmpdir, upload_job_id, "pitstop_status.json")
  @log_hash['expected_pitstop_pdf_filepath'] = ps_pdf

  # get ps_status, rm PS_INPROGRESS file
  ps_results = getPitstopStatus(ps_json, ps_pdf, 6, 15, pitstop_inprogress, 'get_pitstop_status')
  @log_hash['ps_results'] = ps_results

  # copy completed file back to done_dir, or write ERROR file
  if ps_results.strip().downcase() == 'success'
    copyProcessedFile(ps_pdf, final_pdf_filename, 'copy_processed_file_back_to_done_dir')
  else
    writeErrorFile(pitstop_error, 'write_pitstop_err_file')
  end
end

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
