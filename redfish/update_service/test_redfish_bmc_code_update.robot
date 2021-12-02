*** Settings ***
Documentation            Update firmware on a target BMC via Redifsh.

# Test Parameters:
# IMAGE_FILE_PATH        The path to the BMC image file.
#
# Firmware update states:
#     Enabled            Image is installed and either functional or active.
#     Disabled           Image installation failed or ready for activation.
#     Updating           Image installation currently in progress.

Resource                 ../../lib/resource.robot
Resource                 ../../lib/bmc_redfish_resource.robot
Resource                 ../../lib/openbmc_ffdc.robot
Resource                 ../../lib/common_utils.robot
Resource                 ../../lib/code_update_utils.robot
Resource                 ../../lib/dump_utils.robot
Resource                 ../../lib/logging_utils.robot
Resource                 ../../lib/redfish_code_update_utils.robot
Resource                 ../../lib/utils.robot
Resource                 ../../lib/bmc_redfish_utils.robot
Library                  ../../lib/gen_robot_valid.py
Library                  ../../lib/tftp_update_utils.py
Library                  ../../lib/gen_robot_keyword.py

Suite Setup              Suite Setup Execution
Suite Teardown           Suite Teardown Execution
Test Setup               Printn
Test Teardown            FFDC On Test Case Fail

Force Tags               BMC_Code_Update

*** Variables ***

@{ADMIN}          admin_user  TestPwd123
&{USERS}          Administrator=${ADMIN}

*** Test Cases ***
Redfish Code Update With ApplyTime OnReset
    [Documentation]  Update the firmware image with ApplyTime of OnReset.
    [Tags]  Redfish_Code_Update_With_ApplyTime_OnReset
    [Template]  Redfish Update Firmware

    # policy
    OnReset  ${IMAGE0_FILE_PATH}

Redfish Code Update With ApplyTime Immediate
    [Documentation]  Update the firmware image with ApplyTime of Immediate.
    [Tags]  Redfish_Code_Update_With_ApplyTime_Immediate
    [Template]  Redfish Update Firmware

    # policy
    Immediate  ${IMAGE1_FILE_PATH}

Redfish Code Update With Multiple Firmware
    [Documentation]  Update the firmware image with ApplyTime of Immediate.
    [Tags]  Redfish_Code_Update_With_Multiple_Firmware
    [Template]  Redfish Multiple Upload Image And Check Progress State

    # policy   image_file_path     alternate_image_file_path
    OnReset  ${IMAGE2_FILE_PATH}  ${IMAGE_FILE_PATH}


Verify If The Modified Admin Credential Is Valid Post Image Switched To Backup
    [Documentation]  Verify updated admin credential remain same post switch to back up image.
    [Tags]  Verify_If_The_Modified_Admin_Credentails_Is_Valid_Backup_Image
    [Setup]  Create Users With Different Roles  users=${USERS}  force=${True}
    [Teardown]  Run Keywords  Redfish.Login  AND  Delete BMC Users Via Redfish  users=${USERS}

    ${post_code_update_actions}=  Get Post Boot Action
    ${state}=  Get Pre Reboot State
    Expire And Update New Password Via Redfish  ${ADMIN[0]}  ${ADMIN[1]}  0penBmc123

    Redfish.Login
    # change to backup image and reset the BMC.
    Switch Backup Firmware Image To Functional
    Wait For Reboot  start_boot_seconds=${state['epoch_seconds']}

    # verify modified admin password on backup image.
    Redfish.Login  admin_user  0penBmc123
    Redfish.Logout


Verify If The Modified Admin Credential Is Valid Post Update
    [Documentation]  Verify updated admin credential remain same post code update image.
    [Tags]  Verify_If_The_Modified_Admin_Credentails_Is_Valid_Post_Update
    [Setup]  Create Users With Different Roles  users=${USERS}  force=${True}
    [Teardown]  Run Keywords  Redfish.Login  AND  Delete BMC Users Via Redfish  users=${USERS}

    Expire And Update New Password Via Redfish  ${ADMIN[0]}  ${ADMIN[1]}  0penBmc123

    Redfish.Login
    # Flash latest firmware using redfish.
    Redfish Update Firmware  OnReset  ${IMAGE0_FILE_PATH}

    # verify modified admin credentails on latest image.
    Redfish.Login  admin_user  0penBmc123
    Redfish.Logout

*** Keywords ***

Suite Setup Execution
    [Documentation]  Do the suite setup.

    # Checking for file existence.
    Valid File Path  IMAGE_FILE_PATH
    Valid File Path  IMAGE0_FILE_PATH
    Valid File Path  IMAGE1_FILE_PATH
    Valid File Path  IMAGE2_FILE_PATH

    Redfish.Login
    Redfish Delete All BMC Dumps
    Redfish Purge Event Log


Redfish Update Firmware
    [Documentation]  Update the BMC firmware via redfish interface.
    [Arguments]  ${apply_time}  ${image_file_path}

    # Description of argument(s):
    # policy     ApplyTime allowed values (e.g. "OnReset", "Immediate").

    ${post_code_update_actions}=  Get Post Boot Action
    ${state}=  Get Pre Reboot State
    Rprint Vars  state
    Set ApplyTime  policy=${apply_Time}
    Redfish Upload Image  /redfish/v1/UpdateService  ${image_file_path}
    Reboot BMC And Verify BMC Image
    ...  ${apply_time}  start_boot_seconds=${state['epoch_seconds']}  image_file_path=${image_file_path}
    Redfish.Login
    Redfish Verify BMC Version  ${IMAGE_FILE_PATH}
    Verify Get ApplyTime  ${apply_time}


Redfish Multiple Upload Image And Check Progress State
    [Documentation]  Update multiple BMC firmware via redfish interface and check status.
    [Arguments]  ${apply_time}  ${IMAGE_FILE_PATH}  ${ALTERNATE_IMAGE_FILE_PATH}

    # Description of argument(s):
    # apply_time                 ApplyTime allowed values (e.g. "OnReset", "Immediate").
    # IMAGE_FILE_PATH            The path to BMC image file.
    # ALTERNATE_IMAGE_FILE_PATH  The path to alternate BMC image file.

    ${post_code_update_actions}=  Get Post Boot Action
    Valid File Path  ALTERNATE_IMAGE_FILE_PATH
    ${state}=  Get Pre Reboot State
    Rprint Vars  state

    Set ApplyTime  policy=${apply_time}

    ${image_version}=  Get Version Tar  ${IMAGE_FILE_PATH}
    Rprint Vars  image_version
    Redfish Upload Image  ${REDFISH_BASE_URI}UpdateService  ${IMAGE_FILE_PATH}
    Sleep  60s
    ${image_info}=  Get Software Inventory State By Version  ${image_version}
    ${first_image_id}=  Get Image Id By Image Info  ${image_info}
    Rprint Vars  first_image_id
    Sleep  30s

    ${image_version}=  Get Version Tar  ${ALTERNATE_IMAGE_FILE_PATH}
    Rprint Vars  image_version
    Redfish Upload Image  ${REDFISH_BASE_URI}UpdateService  ${ALTERNATE_IMAGE_FILE_PATH}
    Sleep  60s
    ${image_info}=  Get Software Inventory State By Version  ${image_version}
    ${second_image_id}=  Get Image Id By Image Info  ${image_info}
    Rprint Vars  second_image_id

    #Check Image Update Progress State
    #...  match_state='Updating', 'Disabled'  image_id=${first_image_id}

    #Check Image Update Progress State
    #...  match_state='Updating'  image_id=${second_image_id}

    Wait Until Keyword Succeeds  8 min  20 sec
    ...  Check Image Update Progress State
    ...    match_state='Enabled'  image_id=${second_image_id}

    Reboot BMC And Verify BMC Image
    ...  ${apply_time}  start_boot_seconds=${state['epoch_seconds']}  image_file_path=${ALTERNATE_IMAGE_FILE_PATH}

Get Image Id By Image Info
    [Documentation]  Get image ID from image_info.
    [Arguments]  ${image_info}

    [Return]  ${image_info["image_id"]}

Suite Teardown Execution
    [Documentation]  Do the suite level teardown.

    OBMC Reboot (off)
