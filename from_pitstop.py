#  a quick script to write out pitstop_status to a json file

import sys
import os
import json
import logging
from datetime import datetime


# # # Define key vars and params from input & env
inputfile = sys.argv[1]
# the relative order of these passed params is set in flask/instance/config.py
job_id = sys.argv[2]
pitstop_status = sys.argv[3]  # expecting "success" upon success

# paths, vars
tmpdir = os.path.dirname(inputfile)
ps_json = os.path.join(tmpdir, 'pitstop_status.json')
ps_dict = {'pitstop_status': pitstop_status}
infile_name = os.path.basename(inputfile)
this_script = os.path.basename(sys.argv[0])
logfile = os.path.join(tmpdir, "{}-{}.log".format(this_script.replace('.','_'), datetime.now().strftime("%y-%m")))


#---------------------  FUNCTION

def writeJSON(dictname, filename):
    try:
        with open(filename, 'w') as outfile:
            json.dump(dictname, outfile, indent=4, separators=(', ', ': '))
        logging.debug("wrote dict to json file '%s'" % filename)
    except Exception as e:
        logging.error('Failed write JSON file, exiting', exc_info=True)

#---------------------  MAIN

if __name__ == '__main__':
    # init logging
    logging.basicConfig(filename=logfile, level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s", datefmt='%Y-%m-%d %H:%M:%S', force=True)
    logging.debug("* * * * * * running {} for file: '{}'".format(this_script, infile_name))

    writeJSON(ps_dict, ps_json)
