import sys
import os
import json
from lxml import etree
import imp
from datetime import datetime
import logging
import subprocess


# Define harcoded relative import paths from other repos
pitstop_repo = os.path.dirname(sys.argv[0])
resources_dir = os.path.join(pitstop_repo, '..')
bookmaker_connectors_repo = os.path.join(resources_dir, 'bookmaker_connectors')
api_POST_to_flask = imp.load_source('api_POST_to_flask', os.path.join(bookmaker_connectors_repo,'api_POST_to_flask.py'))

# # # Define key vars and params from input & env
inputfile = sys.argv[1]
# the relative order of these passed params is set in flask/instance/config.py
pitstop_setting = sys.argv[2]
job_id = sys.argv[3]
environment = sys.argv[4]  # expecting "staging" or "prod"
infile_name = os.path.basename(inputfile)
this_script = os.path.basename(sys.argv[0])
ps_status = 'n-a'
api_response = 'n-a'

# define local paths to config items
pitstop_exec_cfg_json = os.path.join(pitstop_repo, "pitstop_exec_cfg.json")
pitstop_api_cfg_json = os.path.join(pitstop_repo, "pitstop_api_cfg.json")
pitstop_imprint_defaults_json = os.path.join(pitstop_repo, "pitstop_imprint_defaults.json")
cli_configs_dir = os.path.join(pitstop_repo, 'pitstop_CLI_configs')
# logpath
logdir = os.path.join("S:", os.sep, 'pitstop_exec_logs')
logfile = os.path.join(logdir, "{}-{}.log".format(this_script.replace('.','_'), datetime.now().strftime("%y-%m")))
# tmpdir and outfile paths
tmpdir_base = os.path.join("S:", os.sep, 'pitstop_exec_tmp')
tmpdir = os.path.join(tmpdir_base, job_id)
outfile = os.path.join(tmpdir, infile_name)
pdf_report = os.path.join(tmpdir, 'ps_log.pdf')
task_report = os.path.join(tmpdir, 'task_report.xml')


#---------------------  FUNCTIONS

def try_create_dir(newpath):
    try:
        logging.debug("creating dir: {}".format(newpath))
        if not os.path.exists(newpath):
            os.makedirs(newpath)
    except Exception as e:
        logging.warning('Destination dir "{}" could not be created'.format(newpath), exc_info=True)

def readJSON(filename):
    try:
        with open(filename) as json_data:
            d = json.load(json_data)
            logging.debug("reading in json file %s" % filename)
            return d
    except Exception as e:
        logging.warning("error readin json file {}".format(filename), exc_info=True)
        return {}

def checkTaskReport(tr_xml):
    trstatus = ''
    try:
        if os.path.exists(tr_xml):
            with open(tr_xml) as fobj:
                xml = fobj.read()
                xml = bytes(bytearray(xml, encoding='utf-8'))
                root = etree.XML(xml)
                ns = {"tr": "http://www.enfocus.com/PitStop/13/PitStopServerCLI_TaskReport.xsd"}
                exitcode = int(root.find('.//tr:ExitCode', ns).text)
                if exitcode is not None and int(exitcode.text) == 0:
                    errs = int(root.find('.//tr:ProcessResults/tr:Errors', ns).text)
                    fails = int(root.find('.//tr:ProcessResults/tr:Failures', ns).text)
                    fixes = int(root.find('.//tr:ProcessResults/tr:Fixes', ns).text)
                    ncfails = int(root.find('.//tr:ProcessResults/tr:NonCriticalFailures', ns).text)
                    if errs > 0 or fails > 0 or ncfails > 0 or fixes == 0:
                        trstatus = 'Problem indicated in ps>taskreport>ProcessResults'
                        logging.warning('{}: {} Errors, {} Failures, {} NonCriticalFailures, {} Fixes'.format(trstatus,errs,fails,ncfails,fixes))
                    else:
                        trstatus = 'ok'
                else:
                    trstatus = 'Problem indicated in taskreport: nonzero exitcode or exitcode is None'
        else:
            trstatus = 'pitstop task report not present'
        return trstatus
    except Exception as e:
        logging.error("error checking ps_task_report", exc_info=True)
        return "error checking ps_task_report"

# kickoff process via subprocess.popen.communicate
def invokeSynchronousSubprocess(popen_params):
    logging.info("invoking pitstop cli; parameters: {}".format(ps_params))
    p = ''
    output = ''
    exitcode = ''
    try:
        p = subprocess.Popen(popen_params, stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
        logging.info("pitstop subprocess initiated, pid {}".format(p.pid))
        output = p.communicate()[0]
        exitcode = p.returncode
        logging.info("pitstop exitcode: '{}', output: '{}'".format(exitcode, output))
        return exitcode, output
    except Exception as e:
        logging.error("error invoking pitstop subprocess", exc_info=True)
        return 1, 'error occurred invoking pitstop subprocess'

#---------------------  MAIN

if __name__ == '__main__':
    try:
        # init logging
        try_create_dir(logdir)
        logging.basicConfig(filename=logfile, level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s", datefmt='%Y-%m-%d %H:%M:%S', force=True)
        logging.info("* * * * * * running {} for file: '{}'".format(this_script, infile_name))

        # set values from configs
        pitstop_exec_cfg_data = readJSON(pitstop_exec_cfg_json)
        pitstop_api_cfg_data = readJSON(pitstop_api_cfg_json)
        pitstop_imprint_defaults_data = readJSON(pitstop_imprint_defaults_json)
        cli_bin = pitstop_exec_cfg_data['pitstop_CLI_exe']
        default_setting = pitstop_imprint_defaults_data['default']
        if environment == 'prod':
            api_url = pitstop_api_cfg_data['from_pitstop_url_prod']
            api_uname = pitstop_api_cfg_data['from_pitstop_credentials_prod']['uname']
            api_pw = pitstop_api_cfg_data['from_pitstop_credentials_prod']['pw']
        else:
            api_url = pitstop_api_cfg_data['from_pitstop_url_stg']
            api_uname = pitstop_api_cfg_data['from_pitstop_credentials_stg']['uname']
            api_pw = pitstop_api_cfg_data['from_pitstop_credentials_stg']['pw']

        # create tmpdir
        try_create_dir(tmpdir)

        # get pitstop setting, setup params
        ps_cfg_xml = os.path.join(cli_configs_dir, '{}.xml'.format(pitstop_setting))
        if not os.path.exists(ps_cfg_xml):
            ps_cfg_xml = os.path.join(cli_configs_dir, '{}.xml'.format(default_setting))
        ps_params = [
            cli_bin,
            '-input', inputfile,
            '-output', outfile,
            '-config', ps_cfg_xml,
            '-taskreport', task_report,
            '-reportPDF', pdf_report
            ]
        # run ps on file: expected exitcode on success is 0
        ps_exitcode, output = invokeSynchronousSubprocess(ps_params)

        # check task report: return on success is 'ok'
        ps_results = checkTaskReport(task_report)

        # set status value for return
        if ps_exitcode == 0 and ps_results == 'ok':
            ps_status = 'success'
            logging.info("returning ps_status value: {}".format(ps_status))
        else:
            if ps_exitcode != 0:
                ps_status = output
            elif ps_results != 'ok':
                ps_status = ps_results
            logging.warn("returning ps_status value: {}".format(ps_status))

        # run api: response upon successful transaction is 'Success'
        api_response = api_POST_to_flask.apiPOST(outfile, api_url, api_uname, api_pw, {'job_id': job_id, 'ps_status': ps_status})

    except Exception as e:
        logging.error("untrapped top-level exception occurred", exc_info=True)
        api_response = api_POST_to_flask.apiPOST(inputfile, api_url, api_uname, api_pw, {'job_id': job_id, 'ps_status': 'untrapped top-level exception'})

    finally:
        logging.info("api_response value: {}".format(api_response))
