*** Settings ***
Documentation  This module provides general keywords for dump.

Library         bmc_ssh_utils.py

*** Variables ***

*** Keywords ***

Create User Initiated Dump
    [Documentation]  Generate user initiated dump and return
    ...  the dump id number (e.g., "5").  Optionally return EMPTY
    ...  if out of dump space.
    [Arguments]   ${check_out_of_space}=${False}

    # Description of Argument(s):
    # check_out_of_space   If ${False}, a dump will be created and
    #                      its dump_id will be returned.
    #                      If ${True}, either the dump_id will be
    #                      returned, or the value ${EMPTY} will be
    #                      returned if out of dump space was
    #                      detected when creating the dump.

    ${resp}=  OpenBMC Get Request  ${REST_DUMP_URI}
    Run Keyword If  '${resp.status_code}' == '${HTTP_NOT_FOUND}'
    ...  Set Global Variable  ${REST_DUMP_URI}  /xyz/openbmc_project/dump/

    ${data}=  Create Dictionary  data=@{EMPTY}
    ${resp}=  OpenBMC Post Request
    ...  ${REST_DUMP_URI}action/CreateDump  data=${data}  quiet=${1}

    Run Keyword If  '${check_out_of_space}' == '${False}'
    ...      Run Keyword And Return  Get The Dump Id  ${resp}
    ...  ELSE
    ...      Run Keyword And Return  Check For Too Many Dumps  ${resp}


Get The Dump Id
    [Documentation]  Wait for the dump to be created. Return the
    ...  dump id number (e.g., "5").
    [Arguments]  ${resp}

    # Description of Argument(s):
    # resp   Response object from action/Create Dump attempt.
    #        Example object:
    #        {
    #           "data": 5,
    #           "message": "200 OK",
    #           "status": "ok"
    #        },
    #        The "data" field conveys the id number of the created dump.

    Should Be Equal As Strings  ${resp.status_code}  ${HTTP_OK}

    Run Keyword If  ${resp.json()["data"]} == ${None}
    ...  Fail  Dump id returned null.

    ${dump_id}=  Set Variable  ${json["data"]}

    Wait Until Keyword Succeeds  3 min  15 sec  Check Dump Existence
    ...  ${dump_id}

    [Return]  ${dump_id}


Check For Too Many Dumps
    [Documentation]  Return the dump_id number, or return ${EMPTY} if dump
    ...  creation failed due to too many dumps.
    [Arguments]  ${resp}

    # Description of Argument(s):
    # resp   Response object from action/Create Dump attempt.
    #        Example object if there are too many dumps:
    #       {
    #           "data": {
    #               "description": "xyz.openbmc_project.Dump.Create.Error.QuotaExceeded"
    #           },
    #           "message": "Dump not captured due to a cap.",
    #           "status": "error"
    #       }

    # If dump was created normally, return the dump_id number.
    Run Keyword If  '${resp.status_code}' == '${HTTP_OK}'
    ...  Run Keyword And Return  Get The Dump Id  ${resp}

    ${exception}=  Set Variable  ${resp.json()["message"]}
    ${at_capacity}=  Set Variable  Dump not captured due to a cap
    ${too_many_dumps}=  Evaluate  $at_capacity in $exception
    Printn
    Rprint Vars   exception  too_many_dumps
    # If there are too many dumps, return ${EMPTY}, otherwise Fail.
    ${status}=  Run Keyword If  ${too_many_dumps}  Set Variable  ${EMPTY}
    ...  ELSE  Fail  msg=${exception}.

    [Return]  ${status}


Verify No Dump In Progress
    [Documentation]  Verify no dump in progress.

    ${dump_progress}  ${stderr}  ${rc}=  BMC Execute Command  ls /tmp
    Should Not Contain  ${dump_progress}  obmcdump


Check Dump Existence
    [Documentation]  Verify if given dump exist.
    [Arguments]  ${dump_id}

    # Description of Argument(s):
    # dump_id  An integer value that identifies a particular dump
    #          object(e.g. 1, 3, 5).

    ${resp}=  OpenBMC Get Request  ${REST_DUMP_URI}
    Run Keyword If  '${resp.status_code}' == '${HTTP_NOT_FOUND}'
    ...  Set Global Variable  ${DUMP_ENTRY_URI}  /xyz/openbmc_project/dump/entry/

    ${resp}=  OpenBMC Get Request  ${DUMP_ENTRY_URI}${dump_id}
    Should Be Equal As Strings  ${resp.status_code}  ${HTTP_OK}


Delete BMC Dump
    [Documentation]  Deletes a given bmc dump.
    [Arguments]  ${dump_id}

    # Description of Argument(s):
    # dump_id  An integer value that identifies a particular dump (e.g. 1, 3).

    ${resp}=  OpenBMC Get Request  ${REST_DUMP_URI}
    Run Keyword If  '${resp.status_code}' == '${HTTP_NOT_FOUND}'
    ...  Set Global Variable  ${DUMP_ENTRY_URI}  /xyz/openbmc_project/dump/entry/

    ${args}=  Set Variable   {"data": []}
    ${resp}=  OpenBMC Post Request
    ...  ${DUMP_ENTRY_URI}${dump_id}/action/Delete  data=${args}

    Should Be Equal As Strings  ${resp.status_code}  ${HTTP_OK}

Delete All Dumps
    [Documentation]  Delete all dumps.

    ${resp}=  OpenBMC Get Request  ${REST_DUMP_URI}
    Run Keyword If  '${resp.status_code}' == '${HTTP_NOT_FOUND}'
    ...  Set Global Variable  ${DUMP_ENTRY_URI}  /xyz/openbmc_project/dump/entry/

    # Check if dump entries exist, if not return.
    ${resp}=  OpenBMC Get Request  ${DUMP_ENTRY_URI}list  quiet=${1}
    Return From Keyword If  ${resp.status_code} == ${HTTP_NOT_FOUND}

    # Get the list of dump entries and delete them all.
    ${dump_entries}=  Get URL List  ${DUMP_ENTRY_URI}
    FOR  ${entry}  IN  @{dump_entries}
        ${dump_id}=  Fetch From Right  ${entry}  /
        Delete BMC Dump  ${dump_id}
    END


Redfish Delete BMC Dump
    [Documentation]  Deletes a given BMC dump via Redfish..
    [Arguments]  ${dump_id}

    # Description of Argument(s):
    # dump_id  An integer value that identifies a particular dump (e.g. 1, 3).

    Redfish.Delete  /redfish/v1/Managers/bmc/LogServices/Dump/Entries/${dump_id}


Redfish Delete All BMC Dumps
    [Documentation]  Delete all BMC dumps via Redfish.

    # Check if dump entries exist, if not return.
    ${resp}=  Redfish.Get  /redfish/v1/Managers/bmc/LogServices/Dump/Entries
    Return From Keyword If  ${resp.dict["Members@odata.count"]} == ${0}

    Redfish.Post  /redfish/v1/Managers/bmc/LogServices/Dump/Actions/LogService.ClearLog


Redfish Delete All System Dumps
    [Documentation]  Delete all system  dumps via Redfish.

    Redfish.Post  /redfish/v1/Systems/system/LogServices/Dump/Actions/LogService.ClearLog


Delete All BMC Dump
    [Documentation]  Delete all BMC dump entries using "DeleteAll" interface.

    ${resp}=  OpenBMC Get Request  ${REST_DUMP_URI}
    Run Keyword If  '${resp.status_code}' == '${HTTP_NOT_FOUND}'
    ...  Set Global Variable  ${REST_DUMP_URI}  /xyz/openbmc_project/dump/

    ${args}=  Set Variable   {"data": []}
    ${resp}=  Openbmc Post Request  ${REST_DUMP_URI}action/DeleteAll  data=${args}
    Should Be Equal As Strings  ${resp.status_code}  ${HTTP_OK}

Dump Should Not Exist
    [Documentation]  Verify that BMC dumps do not exist.

    ${resp}=  OpenBMC Get Request  ${REST_DUMP_URI}
    Run Keyword If  '${resp.status_code}' == '${HTTP_NOT_FOUND}'
    ...  Set Global Variable  ${DUMP_ENTRY_URI}  /xyz/openbmc_project/dump/entry/

    ${resp}=  OpenBMC Get Request  ${DUMP_ENTRY_URI}list  quiet=${1}
    Should Be Equal As Strings  ${resp.status_code}  ${HTTP_NOT_FOUND}

Check Existence Of BMC Dump File
    [Documentation]  Verify existence of BMC dump file.
    [Arguments]  ${dump_id}

    # Description of argument(s):
    # dump_id  BMC dump identifier

    ${dump_check_cmd}=  Set Variable
    ...  ls /var/lib/phosphor-debug-collector/dumps

    # Output of sample BMC Execute command with '2' as dump id is as follows
    # ls /var/lib/phosphor-debug-collector/dumps/2
    # obmcdump_2_XXXXXXXXXX.tar.xz
    ${file_there}  ${stderr}  ${rc}=  BMC Execute Command
    ...  ${dump_check_cmd}/${dump_id}
    Should End With  ${file_there}  tar.xz  msg=BMC dump file not found.

Get Dump Entries
    [Documentation]  Return dump entries list.

    ${resp}=  OpenBMC Get Request  ${REST_DUMP_URI}
    Run Keyword If  '${resp.status_code}' == '${HTTP_NOT_FOUND}'
    ...  Set Global Variable  ${DUMP_ENTRY_URI}  /xyz/openbmc_project/dump/entry/

    ${dump_entries}=  Get URL List  ${DUMP_ENTRY_URI}
    [Return]  ${dump_entries}

Trigger Core Dump
    [Documentation]  Trigger core dump.

    # Find the pid of the active ipmid and kill it.
    ${cmd_buf}=  Catenate  kill -s SEGV $(ps | egrep ' ipmid$' |
    ...  egrep -v grep | \ cut -c1-6)

    ${cmd_output}  ${stderr}  ${rc}=  BMC Execute Command  ${cmd_buf}
    Should Be Empty  ${stderr}  msg=BMC execute command error.
    Should Be Equal As Integers  ${rc}  ${0}
    ...  msg=BMC execute command return code is not zero.

Initiate BMC Dump Using Redfish And Return Task Id
     [Documentation]  Initiate BMC dump via Redfish and return its task ID.

     ${payload}=  Create Dictionary  DiagnosticDataType=Manager
     ${resp}=  Redfish.Post
     ...  /redfish/v1/Managers/bmc/LogServices/Dump/Actions/LogService.CollectDiagnosticData
     ...  body=${payload}  valid_status_codes=[${HTTP_ACCEPTED}]

     # Example of response from above Redfish POST request.
     # "@odata.id": "/redfish/v1/TaskService/Tasks/0",
     # "@odata.type": "#Task.v1_4_3.Task",
     # "Id": "0",
     # "TaskState": "Running",
     # "TaskStatus": "OK"

     [Return]  ${resp.dict['Id']}

Create User Initiated BMC Dump Via Redfish
    [Documentation]  Generate user initiated BMC dump via Redfish and return the dump id number (e.g., "5").

    ${payload}=  Create Dictionary  DiagnosticDataType=Manager
    ${resp}=  Redfish.Post  /redfish/v1/Managers/bmc/LogServices/Dump/Actions/LogService.CollectDiagnosticData
    ...  body=${payload}  valid_status_codes=[${HTTP_ACCEPTED}]

    # Example of response from above Redfish POST request.
    # "@odata.id": "/redfish/v1/TaskService/Tasks/0",
    # "@odata.type": "#Task.v1_4_3.Task",
    # "Id": "0",
    # "TaskState": "Running",
    # "TaskStatus": "OK"

    Wait Until Keyword Succeeds  5 min  15 sec  Check Task Completion  ${resp.dict['Id']}
    ${task_id}=  Set Variable  ${resp.dict['Id']}

    ${task_dict}=  Redfish.Get Properties  /redfish/v1/TaskService/Tasks/${task_id}

    # Example of HttpHeaders field of task details.
    # "Payload": {
    #   "HttpHeaders": [
    #     "Host: <BMC_IP>",
    #      "Accept-Encoding: identity",
    #      "Connection: Keep-Alive",
    #      "Accept: */*",
    #      "Content-Length: 33",
    #      "Location: /redfish/v1/Managers/bmc/LogServices/Dump/Entries/2"]
    #    ],
    #    "HttpOperation": "POST",
    #    "JsonBody": "{\"DiagnosticDataType\":\"Manager\"}",
    #     "TargetUri": "/redfish/v1/Managers/bmc/LogServices/Dump/Actions/LogService.CollectDiagnosticData"
    # }

    [Return]  ${task_dict["Payload"]["HttpHeaders"][-1].split("/")[-1]}

Auto Generate BMC Dump
    [Documentation]  Auto generate BMC dump.

    ${cmd}=  Catenate  busctl --verbose call xyz.openbmc_project.Dump.Manager
    ...  /xyz/openbmc_project/dump/bmc xyz.openbmc_project.Dump.Create CreateDump a{sv} 0
    ${stdout}  ${stderr}  ${rc}=
    ...  BMC Execute Command  ${cmd}
    [Return]  ${stdout}  ${stderr}  ${rc}

Get Dump Size
    [Documentation]  Get dump size.
    [Arguments]  ${dump_uri}

    # Description of argument(s):
    # dump_uri        Dump URI
    #                 (Eg. 	/xyz/openbmc_project/dump/bmc/entry/1).

    # Example of Dump entry.
    # "data": {
    #   "CompletedTime": 1616760931,
    #   "Elapsed": 1616760931,
    #   "OffloadUri": "",
    #   "Offloaded": false,
    #   "Password": "",
    #   "Size": 3056,
    #   "SourceDumpId": 117440513,
    #   "StartTime": 1616760931,
    #   "Status": "xyz.openbmc_project.Common.Progress.OperationStatus.Completed",
    #   "VSPString": ""
    #  },

    Log  ${dump_uri}
    ${dump_data}=  Redfish.Get Properties  ${dump_uri}
    [Return]  ${dump_data["data"]["Size"]}

Get Dump ID
    [Documentation]  Return dump ID.
    [Arguments]   ${task_id}

    # Description of argument(s):
    # task_id        Task ID.

    # Example of HttpHeaders field of task details.
    # "Payload": {
    #   "HttpHeaders": [
    #     "Host: <BMC_IP>",
    #      "Accept-Encoding: identity",
    #      "Connection: Keep-Alive",
    #      "Accept: */*",
    #      "Content-Length: 33",
    #      "Location: /redfish/v1/Managers/bmc/LogServices/Dump/Entries/2"]
    #    ],
    #    "HttpOperation": "POST",
    #    "JsonBody": "{\"DiagnosticDataType\":\"Manager\"}",
    #     "TargetUri":
    # "/redfish/v1/Managers/bmc/LogServices/Dump/Actions/LogService.CollectDiagnosticData"
    # }

    ${task_dict}=  Redfish.Get Properties  /redfish/v1/TaskService/Tasks/${task_id}
    ${key}  ${value}=  Set Variable  ${task_dict["Payload"]["HttpHeaders"][-1].split(":")}
    Run Keyword If  '${key}' != 'Location'  Fail
    [Return]  ${value.strip('/').split('/')[-1]}

Get Task Status
    [Documentation]  Return task status.
    [Arguments]   ${task_id}

    # Description of argument(s):
    # task_id        Task ID.

    ${resp}=  Redfish.Get Properties  /redfish/v1/TaskService/Tasks/${task_id}
    [Return]  ${resp['TaskState']}

Check Task Completion
    [Documentation]  Check if the task is complete.
    [Arguments]   ${task_id}

    # Description of argument(s):
    # task_id        Task ID.

    ${task_dict}=  Redfish.Get Properties  /redfish/v1/TaskService/Tasks/${task_id}
    Should Be Equal As Strings  ${task_dict['TaskState']}  Completed

Get Dump ID And Status
    [Documentation]  Return dump ID and status.
    [Arguments]   ${task_id}

    # Description of argument(s):
    # task_id        Task ID.

    Wait Until Keyword Succeeds  10 min  15 sec  Check Task Completion  ${task_id}
    ${dump_id}=  Get Dump ID  ${task_id}
    [Return]  ${dump_id}  Completed
