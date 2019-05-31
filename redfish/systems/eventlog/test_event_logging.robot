*** Settings ***
Documentation       Inventory of hardware resources under systems.

Resource            ../../../lib/bmc_redfish_resource.robot
Resource            ../../../lib/bmc_redfish_utils.robot
Resource            ../../../lib/logging_utils.robot
Resource            ../../../lib/openbmc_ffdc.robot

Test Setup          Test Setup Execution
Test Teardown       Test Teardown Execution
Suite Teardown      Suite Teardown Execution

*** Test Cases ***

Event Log Check After BMC Reboot
    [Documentation]  Check event log after BMC rebooted.
    [Tags]  Event_Log_Check_After_BMC_Reboot

    Redfish Purge Event Log
    Event Log Should Not Exist

    Redfish OBMC Reboot (off)

    Redfish.Login
    Wait Until Keyword Succeeds  1 mins  15 secs   Redfish.Get  ${EVENT_LOG_URI}Entries

    Event Log Should Not Exist


Event Log Check After Host Poweron
    [Documentation]  Check event log after host has booted.
    [Tags]  Event_Log_Check_After_Host_Poweron

    Redfish Purge Event Log
    Event Log Should Not Exist

    Redfish Power On

    Redfish.Login
    Event Log Should Not Exist


Create Test Event Log And Verify
    [Documentation]  Create event logs and verify via redfish.
    [Tags]  Create_Test_Event_Log_And_Verify

    Create Test Error Log
    Event Log Should Exist


Test Event Log Persistency On Restart
    [Documentation]  Restart logging service and verify event logs.
    [Tags]  Test_Event_Log_Persistency_On_Restart

    Create Test Error Log
    Event Log Should Exist

    BMC Execute Command
    ...  systemctl restart xyz.openbmc_project.Logging.service
    Sleep  10s  reason=Wait for logging service to restart properly.

    Event Log Should Exist


Test Event Entry Numbering Reset On Restart
    [Documentation]  Restart logging service and verify event logs entry starts
    ...  from entry "Id" 1.
    [Tags]  Test_Event_Entry_Numbering_Reset_On_Restart

    #{
    #  "@odata.context": "/redfish/v1/$metadata#LogEntryCollection.LogEntryCollection",
    #  "@odata.id": "/redfish/v1/Systems/system/LogServices/EventLog/Entries",
    #  "@odata.type": "#LogEntryCollection.LogEntryCollection",
    #  "Description": "Collection of System Event Log Entries",
    #  "Members": [
    #  {
    #    "@odata.context": "/redfish/v1/$metadata#LogEntry.LogEntry",
    #    "@odata.id": "/redfish/v1/Systems/system/LogServices/EventLog/Entries/1",
    #    "@odata.type": "#LogEntry.v1_4_0.LogEntry",
    #    "Created": "2019-05-29T13:19:27+00:00",
    #    "EntryType": "Event",
    #    "Id": "1",               <----- Event log ID
    #    "Message": "org.open_power.Host.Error.Event",
    #    "Name": "System DBus Event Log Entry",
    #    "Severity": "Critical"
    #  }
    #  ],
    #  "Members@odata.count": 1,
    #  "Name": "System Event Log Entries"
    #}

    Create Test Error Log
    Create Test Error Log
    Event Log Should Exist

    Redfish Purge Event Log
    Event Log Should Not Exist

    BMC Execute Command
    ...  systemctl restart xyz.openbmc_project.Logging.service
    Sleep  10s  reason=Wait for logging service to restart properly.

    Create Test Error Log
    ${elogs}=  Get Event Logs
    Should Be Equal  ${elogs[0]["Id"]}  1  msg=Event log entry is not 1.


Test Event Log Persistency On Reboot
    [Documentation]  Reboot BMC and verify event log.
    [Tags]  Test_Event_Log_Persistency_On_Reboot

    Redfish Purge Event Log
    Create Test Error Log
    Event Log Should Exist

    Redfish OBMC Reboot (off)

    Redfish.Login
    Wait Until Keyword Succeeds  1 mins  15 secs   Redfish.Get  ${EVENT_LOG_URI}Entries

    Event Log Should Exist


Create Test Event Log And Verify Time Stamp
    [Documentation]  Create event logs and verify time stamp.
    [Tags]  Create_Test_Event_Log_And_Verify_Time_Stamp

    #{
    #  "@odata.context": "/redfish/v1/$metadata#LogEntryCollection.LogEntryCollection",
    #  "@odata.id": "/redfish/v1/Systems/system/LogServices/EventLog/Entries",
    #  "@odata.type": "#LogEntryCollection.LogEntryCollection",
    #  "Description": "Collection of System Event Log Entries",
    #  "Members": [
    #  {
    #    "@odata.context": "/redfish/v1/$metadata#LogEntry.LogEntry",
    #    "@odata.id": "/redfish/v1/Systems/system/LogServices/EventLog/Entries/1",
    #    "@odata.type": "#LogEntry.v1_4_0.LogEntry",
    #    "Created": "2019-05-29T13:19:27+00:00", <--- Time stamp
    #    "EntryType": "Event",
    #    "Id": "1",
    #    "Message": "org.open_power.Host.Error.Event",
    #    "Name": "System DBus Event Log Entry",
    #    "Severity": "Critical"
    #  }
    #  ],
    #  "Members@odata.count": 1,
    #  "Name": "System Event Log Entries"
    #}

    Redfish Purge Event Log

    Create Test Error Log
    Sleep  2s
    Create Test Error Log

    ${elog_entry}=  Get Event Logs

    # The event log generated is associated with the epoc time and unique
    # for every error and in increasing time stamp.
    ${time_stamp1}=  Convert Date  ${elog_entry[0]["Created"]}  epoch
    ${time_stamp2}=  Convert Date  ${elog_entry[1]["Created"]}  epoch

    Should Be True  ${time_stamp2} > ${time_stamp1}


*** Keywords ***

Suite Teardown Execution
    [Documentation]  Do the post suite teardown.

    Redfish.Logout


Test Setup Execution
   [Documentation]  Do test case setup tasks.

    Redfish.Login

    ${status}=  Run Keyword And Return Status  Logging Test Binary Exist
    Run Keyword If  ${status} == ${False}  Install Tarball


Test Teardown Execution
    [Documentation]  Do the post test teardown.

    FFDC On Test Case Fail
    Redfish Purge Event Log


Event Log Should Not Exist
    [Documentation]  Event log entries should not exist.

    ${elogs}=  Get Event Logs
    Should Be Empty  ${elogs}  msg=System event log entry is not empty.


Event Log Should Exist
    [Documentation]  Event log entries should exist.

    ${elogs}=  Get Event Logs
    Should Not Be Empty  ${elogs}  msg=System event log entry is not empty.
