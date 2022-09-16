# pitstop_watch
A set of scripts to enable bookmaker to interact with a separate pitstop environment via api, and run pitstop configurations via command-line interface.
*Note: Some of the resources discussed below reside in other repos, as reusable micro-service-type tools.

## Requirements
Two config "template" files are provided in the repo, each needs to be copied and renamed (without the '_template' suffix) and edited with actual specifications:
- *pitstop_exec_cfg.json* This file is used to specify the path to the pitstop CLI binary.
- *pitstop_api_cfg.json* This file is used to specify 'to_pitstop' and 'from_pitstop' api urls and credentials, for both production and staging environments. Also specifies the path to 'from_pitstop' upload directory, so bookmaker can find it.
An additional config file is: *pitstop_imprint_defaults.json*. This is used to specify default pitstop configuration and any per imprint defaults.

Additionally, routes for 'to_pitstop' and 'from_pitstop' will need to be configured in _utilities/portable_flask-api/instance/config.py_. Examples of how to configure can be found in _utilities/portable_flask-api/instance/config_template.py_

## Bookmaker<->Pitstop Process Outline
Here is a walkthrough of the Bookmaker<->pitstop process:
1. _pitstop_watch/*send_to_pitstop.rb*_-- As a part of bookmaker toolchain(s) in bookmaker_deploy .bat files, this script determines the pitstop setting, stg/prod environment, api-url, etc., and sends these values as parameters to . . .
2. _bookmaker_connectors/*api_POST_to_flask.py*_-- This script is very generic, it just takes required arguments for standard POST call with basic_auth and optional parameters. It sends the bookmaker pdf and params to the pitstop server, which receives the api via . . .
3. _utilities/*portable_flask-api*_-- A generic api which can host POST routes as specified per instance in _./instance/config.py_. Configurable specifications include upload-dir for files, and an executable to be called with uploaded file as a param (along with other named params). Once this api receives the file from the bookmaker server, it invokes . . .
4. _pitstop_watch/*pitstop_exec.rb*_-- This script runs pitstop via the command line as a synchronous subprocess, and sends the resulting output &/or status of the run (success/error) back to the bookmaker server via api.
    - It determines which pitstop configuration file to use, from _./pitstop_CLI_configs_, based on parameters received. These config files in turn reference pitstop .eal "Action Lists" from _./pitstop_CLI_configs/actionLists_  
    - It sends pitstop pdf output and a 'pistop_status' string (indicating success/errors) back to bookmaker server via api, using . . .
5. _api_POST_to_flask.py_ and _portable_flask-api_-- Same as steps 2 & 3, except this time from pitstop server back to bookmaker server, where the pdf output file is saved and we invoke . . .
6. _pitstop_watch/*from_pitstop.py*_-- A very simple script which writes a json file with the pitstop run's status (success/error), in the same directory as the outfile from pitstop (where bookmaker can come pick them up).
7. _pitstop_watch/*get_pitstop_output.rb*_-- Finally, back in the bookmaker_deploy .bat toolchain, this script checks the expected outdir for the returned pitstop file (every 15 seconds, for up to 90 seconds). If there's no outfile, or pitstop status indicates a problem, it writes an error-file to the bookmaker 'done' dir, and the submitter is notified.
