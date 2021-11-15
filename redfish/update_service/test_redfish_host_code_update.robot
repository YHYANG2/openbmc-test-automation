*** Settings ***
Documentation            Update firmware on a target Host via Redifsh.

# Test Parameters:
# IMAGE_FILE_PATH        The path to the Host image file.
#
# Firmware update states:
#     Enabled            Image is installed and either functional or active.
#     Disabled           Image installation failed or ready for activation.
#     Updating           Image installation currently in progress.

Resource                 ../../lib/resource.robot
Resource                 ../../lib/bmc_redfish_resource.robot
Resource                 ../../lib/boot_utils.robot
Resource                 ../../lib/openbmc_ffdc.robot
Resource                 ../../lib/common_utils.robot
Resource                 ../../lib/code_update_utils.robot
Resource                 ../../lib/dump_utils.robot
Resource                 ../../lib/logging_utils.robot
Resource                 ../../lib/redfish_code_update_utils.robot
Resource                 ../../lib/utils.robot
Library                  ../../lib/gen_robot_valid.py
Library                  ../../lib/tftp_update_utils.py

Suite Setup              Suite Setup Execution
Suite Teardown           Redfish.Logout
Test Setup               Printn
Test Teardown            FFDC On Test Case Fail

Force Tags               Host_Code_Update

*** Test Cases ***

Redfish Host Code Update With ApplyTime OnReset
    [Documentation]  Update the firmware image with ApplyTime of OnReset.
    [Tags]  Redfish_Host_Code_Update_With_ApplyTime_OnReset
    [Template]  Redfish Update Firmware

    # policy
    OnReset  ${IMAGE_HOST_FILE_PATH_0}


Redfish Host Code Update With ApplyTime Immediate
    [Documentation]  Update the firmware image with ApplyTime of Immediate.
    [Tags]  Redfish_Host_Code_Update_With_ApplyTime_Immediate
    [Template]  Redfish Update Firmware

    # policy
    Immediate  ${IMAGE_HOST_FILE_PATH_1}


BMC Reboot When BIOS Update Goes On
    [Documentation]  Trigger BIOS update and do BMC reboot.
    [Tags]  BMC_Reboot_When_BIOS_Update_Goes_On

    Redfish Firmware Update And Do BMC Reboot  ${IMAGE_HOST_FILE_PATH_0}


*** Keywords ***

Suite Setup Execution
    [Documentation]  Do the suite setup.

    Valid File Path  IMAGE_HOST_FILE_PATH_0
    Valid File Path  IMAGE_HOST_FILE_PATH_1
    Redfish.Login
    Run Keyword And Ignore Error  Redfish Delete All BMC Dumps
    Run Keyword And Ignore Error  Redfish Purge Event Log
    Redfish Power Off  stack_mode=skip


Redfish Update Firmware
    [Documentation]  Update the BMC firmware via redfish interface.
    [Arguments]  ${apply_time}  ${image_file_path}

    # Description of argument(s):
    # policy     ApplyTime allowed values (e.g. "OnReset", "Immediate").

    Redfish.Login

    Set ApplyTime  policy=${apply_time}

    # Redfish Upload Image And Check Progress State  ${apply_time}
    # Poweron Host And Verify Host Image  ${apply_time}
    Redfish Upload Image  /redfish/v1/UpdateService  ${image_file_path}
    Sleep  1 mins

    ${image_version}=  Get Version Tar  ${image_file_path}
    ${image_info}=  Get Software Inventory State By Version  ${image_version}
    ${image_id}=  Get Image Id By Image Info  ${image_info}

    Wait Until Keyword Succeeds  1 min  10 sec
    ...  Check Image Update Progress State  match_state='Updating'  image_id=${image_id}

    Wait State  os_running_match_state  15 mins
    Redfish.Login
    Redfish Verify Host Version  ${image_file_path}

Redfish Firmware Update And Do BMC Reboot
    [Documentation]  Update the firmware via redfish interface and do BMC reboot.
    [Arguments]  ${image_file_path}

    Redfish.Login
    Set ApplyTime  policy=Immediate

    Redfish Upload Image  /redfish/v1/UpdateService  ${image_file_path}
    Sleep  1 mins

    ${image_version}=  Get Version Tar  ${image_file_path}
    ${image_info}=  Get Software Inventory State By Version  ${image_version}
    ${image_id}=  Get Image Id By Image Info  ${image_info}

    Wait Until Keyword Succeeds  1 min  10 sec
    ...  Check Image Update Progress State  match_state='Updating'  image_id=${image_id}

    # BMC reboot while BIOS update is in progress.
    Redfish BMC Reset Operation
    Sleep  5s

    ${status}=   Run Keyword And Return Status
    ...    Ping Host  ${OPENBMC_HOST}
    Run Keyword If  '${status}' == '${False}'
    ...    Fail   msg=Ping Failed

    Wait State  os_running_match_state  15 mins

    Redfish.Login
    Redfish Verify Host Version  ${image_file_path}

Get Image Id By Image Info
    [Documentation]  Get image ID from image_info.
    [Arguments]  ${image_info}

    [Return]  ${image_info["image_id"]}
