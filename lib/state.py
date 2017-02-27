#!/usr/bin/env python

r"""
This module contains functions having to do with machine state: get_state,
check_state, wait_state, etc.

The 'State' is a composite of many pieces of data.  Therefore, the functions
in this module define state as an ordered dictionary.  Here is an example of
some test output showing machine state:

default_state:
  default_state[chassis]:                         On
  default_state[bmc]:                             Ready
  default_state[boot_progress]:                   FW Progress, Starting OS
  default_state[host]:                            Running
  default_state[os_ping]:                         1
  default_state[os_login]:                        1
  default_state[os_run_cmd]:                      1

Different users may very well have different needs when inquiring about
state.  Support for new pieces of state information may be added to this
module as needed.

By using the wait_state function, a caller can start a boot and then wait for
a precisely defined state to indicate that the boot has succeeded.  If
the boot fails, they can see exactly why by looking at the current state as
compared with the expected state.
"""

import gen_print as gp
import gen_robot_print as grp
import gen_valid as gv
import gen_robot_utils as gru
import gen_cmd as gc

import commands
from robot.libraries.BuiltIn import BuiltIn
from robot.utils import DotDict

import re
import os

# We need utils.robot to get keywords like "Get Power State".
gru.my_import_resource("utils.robot")
gru.my_import_resource("state_manager.robot")

# The BMC code has recently been changed as far as what states are defined and
# what the state values can be.  This module now has a means of processing both
# the old style state (i.e. OBMC_STATES_VERSION = 0) and the new style (i.e.
# OBMC_STATES_VERSION = 1).
# The caller can set environment variable OBMC_STATES_VERSION to dictate
# whether we're processing old or new style states.  If OBMC_STATES_VERSION is
# not set it will default to 1.

OBMC_STATES_VERSION = int(os.environ.get('OBMC_STATES_VERSION', 1))

# TODO: Re-enable 'bmc' once it is working again.
if OBMC_STATES_VERSION == 0:
    # default_state is an initial value which may be of use to callers.
    default_state = DotDict([('power', '1'),
                             # ('bmc', 'HOST_BOOTED'),
                             ('boot_progress', 'FW Progress, Starting OS'),
                             ('os_ping', '1'),
                             ('os_login', '1'),
                             ('os_run_cmd', '1')])
    # valid_req_states, default_req_states and master_os_up_match are used by
    # the get_state function.
    # valid_req_states is a list of state information supported by the
    # get_state function.
    valid_req_states = ['ping',
                        'packet_loss',
                        'uptime',
                        'epoch_seconds',
                        'power',
                        # 'bmc',
                        'boot_progress',
                        'os_ping',
                        'os_login',
                        'os_run_cmd']
    # When a user calls get_state w/o specifying req_states, default_req_states
    # is used as its value.
    default_req_states = ['power',
                          # 'bmc',
                          'boot_progress',
                          'os_ping',
                          'os_login',
                          'os_run_cmd']
    # A master dictionary to determine whether the os may be up.
    master_os_up_match = DotDict([('power', 'On'),
                                  # ('bmc', '^HOST_BOOTED$'),
                                  ('boot_progress',
                                   'FW Progress, Starting OS')])

else:
    # default_state is an initial value which may be of use to callers.
    default_state = DotDict([('chassis', 'On'),
                             # ('bmc', 'Ready'),
                             ('boot_progress', 'FW Progress, Starting OS'),
                             ('host', 'Running'),
                             ('os_ping', '1'),
                             ('os_login', '1'),
                             ('os_run_cmd', '1')])
    # valid_req_states is a list of state information supported by the
    # get_state function.
    # valid_req_states, default_req_states and master_os_up_match are used by
    # the get_state function.
    valid_req_states = ['ping',
                        'packet_loss',
                        'uptime',
                        'epoch_seconds',
                        'chassis',
                        # 'bmc',
                        'boot_progress',
                        'host',
                        'os_ping',
                        'os_login',
                        'os_run_cmd']
    # When a user calls get_state w/o specifying req_states, default_req_states
    # is used as its value.
    default_req_states = ['chassis',
                          # 'bmc',
                          'boot_progress',
                          'host',
                          'os_ping',
                          'os_login',
                          'os_run_cmd']

    # TODO: Add back boot_progress when ipmi is enabled on Witherspoon.
    # A master dictionary to determine whether the os may be up.
    master_os_up_match = DotDict([('chassis', '^On$'), ('host', '^Running$')])
    # ('bmc', '^Ready$'),
    # ('boot_progress',
    #  'FW Progress, Starting OS')])

# valid_os_req_states and default_os_req_states are used by the os_get_state
# function.
# valid_os_req_states is a list of state information supported by the
# get_os_state function.
valid_os_req_states = ['os_ping',
                       'os_login',
                       'os_run_cmd']
# When a user calls get_os_state w/o specifying req_states,
# default_os_req_states is used as its value.
default_os_req_states = ['os_ping',
                         'os_login',
                         'os_run_cmd']

# Presently, some BMCs appear to not keep time very well.  This environment
# variable directs the get_state function to use either the BMC's epoch time
# or the local epoch time.
USE_BMC_EPOCH_TIME = int(os.environ.get('USE_BMC_EPOCH_TIME', 0))


###############################################################################
def return_default_state():

    r"""
    Return default state dictionary.

    default_state is an initial value which may be of use to callers.
    """

    return default_state

###############################################################################


###############################################################################
def anchor_state(state):

    r"""
    Add regular expression anchors ("^" and "$") to the beginning and end of
    each item in the state dictionary passed in.  Return the resulting
    dictionary.

    Description of Arguments:
    state    A dictionary such as the one returned by the get_state()
             function.
    """

    anchored_state = state.copy()
    for key, match_state_value in anchored_state.items():
        anchored_state[key] = "^" + str(anchored_state[key]) + "$"

    return anchored_state

###############################################################################


###############################################################################
def strip_anchor_state(state):

    r"""
    Strip regular expression anchors ("^" and "$") from the beginning and end
    of each item in the state dictionary passed in.  Return the resulting
    dictionary.

    Description of Arguments:
    state    A dictionary such as the one returned by the get_state()
             function.
    """

    stripped_state = state.copy()
    for key, match_state_value in stripped_state.items():
        stripped_state[key] = stripped_state[key].strip("^$")

    return stripped_state

###############################################################################


###############################################################################
def compare_states(state,
                   match_state):

    r"""
    Compare 2 state dictionaries.  Return True if they match and False if they
    don't.  Note that the match_state dictionary does not need to have an entry
    corresponding to each entry in the state dictionary.  But for each entry
    that it does have, the corresponding state entry will be checked for a
    match.

    Description of arguments:
    state           A state dictionary such as the one returned by the
                    get_state function.
    match_state     A dictionary whose key/value pairs are "state field"/
                    "state value".  The state value is interpreted as a
                    regular expression.  Every value in this dictionary is
                    considered.  If each and every one matches, the 2
                    dictionaries are considered to be matching.
    """

    match = True
    for key, match_state_value in match_state.items():
        try:
            if not re.match(match_state_value, str(state[key])):
                match = False
                break
        except KeyError:
            match = False
            break

    return match

###############################################################################


###############################################################################
def get_os_state(os_host="",
                 os_username="",
                 os_password="",
                 req_states=default_os_req_states,
                 os_up=True,
                 quiet=None):

    r"""
    Get component states for the operating system such as ping, login,
    etc, put them into a dictionary and return them to the caller.

    Note that all substate values are strings.

    Description of arguments:
    os_host      The DNS name or IP address of the operating system.
                 This defaults to global ${OS_HOST}.
    os_username  The username to be used to login to the OS.
                 This defaults to global ${OS_USERNAME}.
    os_password  The password to be used to login to the OS.
                 This defaults to global ${OS_PASSWORD}.
    req_states   This is a list of states whose values are being requested by
                 the caller.
    os_up        If the caller knows that the os can't possibly be up, it can
                 improve performance by passing os_up=False.  This function
                 will then simply return default values for all requested os
                 sub states.
    quiet        Indicates whether status details (e.g. curl commands) should
                 be written to the console.
                 Defaults to either global value of ${QUIET} or to 1.
    """

    quiet = grp.set_quiet_default(quiet, 1)

    # Set parm defaults where necessary and validate all parms.
    if os_host == "":
        os_host = BuiltIn().get_variable_value("${OS_HOST}")
    error_message = gv.svalid_value(os_host, var_name="os_host",
                                    invalid_values=[None, ""])
    if error_message != "":
        BuiltIn().fail(gp.sprint_error(error_message))

    if os_username == "":
        os_username = BuiltIn().get_variable_value("${OS_USERNAME}")
    error_message = gv.svalid_value(os_username, var_name="os_username",
                                    invalid_values=[None, ""])
    if error_message != "":
        BuiltIn().fail(gp.sprint_error(error_message))

    if os_password == "":
        os_password = BuiltIn().get_variable_value("${OS_PASSWORD}")
    error_message = gv.svalid_value(os_password, var_name="os_password",
                                    invalid_values=[None, ""])
    if error_message != "":
        BuiltIn().fail(gp.sprint_error(error_message))

    invalid_req_states = [sub_state for sub_state in req_states
                          if sub_state not in valid_os_req_states]
    if len(invalid_req_states) > 0:
        error_message = "The following req_states are not supported:\n" +\
            gp.sprint_var(invalid_req_states)
        BuiltIn().fail(gp.sprint_error(error_message))

    # Initialize all substate values supported by this function.
    os_ping = 0
    os_login = 0
    os_run_cmd = 0

    if os_up:
        if 'os_ping' in req_states:
            # See if the OS pings.
            cmd_buf = "ping -c 1 -w 2 " + os_host
            if not quiet:
                grp.rpissuing(cmd_buf)
            rc, out_buf = commands.getstatusoutput(cmd_buf)
            if rc == 0:
                os_ping = 1

        # Programming note: All attributes which do not require an ssh login
        # should have been processed by this point.
        master_req_login = ['os_login', 'os_run_cmd']
        req_login = [sub_state for sub_state in req_states if sub_state in
                     master_req_login]

        must_login = (len([sub_state for sub_state in req_states
                           if sub_state in master_req_login]) > 0)

        if must_login:
            # Open SSH connection to OS.
            cmd_buf = ["Open Connection", os_host]
            if not quiet:
                grp.rpissuing_keyword(cmd_buf)
            ix = BuiltIn().run_keyword(*cmd_buf)

            # Login to OS.
            cmd_buf = ["Login", os_username, os_password]
            if not quiet:
                grp.rpissuing_keyword(cmd_buf)
            status, msg = BuiltIn().run_keyword_and_ignore_error(*cmd_buf)
            if status == "PASS":
                os_login = 1

            if os_login:
                if 'os_run_cmd' in req_states:
                    if os_login:
                        # Try running a simple command (uptime) on the OS.
                        cmd_buf = ["Execute Command", "uptime",
                                   "return_stderr=True", "return_rc=True"]
                        if not quiet:
                            grp.rpissuing_keyword(cmd_buf)
                        output, stderr_buf, rc = \
                            BuiltIn().run_keyword(*cmd_buf)
                        if rc == 0 and stderr_buf == "":
                            os_run_cmd = 1

    os_state = DotDict()
    for sub_state in req_states:
        cmd_buf = "os_state['" + sub_state + "'] = str(" + sub_state + ")"
        exec(cmd_buf)

    return os_state

###############################################################################


###############################################################################
def get_state(openbmc_host="",
              openbmc_username="",
              openbmc_password="",
              os_host="",
              os_username="",
              os_password="",
              req_states=default_req_states,
              quiet=None):

    r"""
    Get component states such as power state, bmc state, etc, put them into a
    dictionary and return them to the caller.

    Note that all substate values are strings.

    Description of arguments:
    openbmc_host      The DNS name or IP address of the BMC.
                      This defaults to global ${OPENBMC_HOST}.
    openbmc_username  The username to be used to login to the BMC.
                      This defaults to global ${OPENBMC_USERNAME}.
    openbmc_password  The password to be used to login to the BMC.
                      This defaults to global ${OPENBMC_PASSWORD}.
    os_host           The DNS name or IP address of the operating system.
                      This defaults to global ${OS_HOST}.
    os_username       The username to be used to login to the OS.
                      This defaults to global ${OS_USERNAME}.
    os_password       The password to be used to login to the OS.
                      This defaults to global ${OS_PASSWORD}.
    req_states        This is a list of states whose values are being requested
                      by the caller.
    quiet             Indicates whether status details (e.g. curl commands)
                      should be written to the console.
                      Defaults to either global value of ${QUIET} or to 1.
    """

    quiet = grp.set_quiet_default(quiet, 1)

    # Set parm defaults where necessary and validate all parms.
    if openbmc_host == "":
        openbmc_host = BuiltIn().get_variable_value("${OPENBMC_HOST}")
    error_message = gv.svalid_value(openbmc_host,
                                    var_name="openbmc_host",
                                    invalid_values=[None, ""])
    if error_message != "":
        BuiltIn().fail(gp.sprint_error(error_message))

    if openbmc_username == "":
        openbmc_username = BuiltIn().get_variable_value("${OPENBMC_USERNAME}")
    error_message = gv.svalid_value(openbmc_username,
                                    var_name="openbmc_username",
                                    invalid_values=[None, ""])
    if error_message != "":
        BuiltIn().fail(gp.sprint_error(error_message))

    if openbmc_password == "":
        openbmc_password = BuiltIn().get_variable_value("${OPENBMC_PASSWORD}")
    error_message = gv.svalid_value(openbmc_password,
                                    var_name="openbmc_password",
                                    invalid_values=[None, ""])
    if error_message != "":
        BuiltIn().fail(gp.sprint_error(error_message))

    # NOTE: OS parms are optional.
    if os_host == "":
        os_host = BuiltIn().get_variable_value("${OS_HOST}")
        if os_host is None:
            os_host = ""

    if os_username is "":
        os_username = BuiltIn().get_variable_value("${OS_USERNAME}")
        if os_username is None:
            os_username = ""

    if os_password is "":
        os_password = BuiltIn().get_variable_value("${OS_PASSWORD}")
        if os_password is None:
            os_password = ""

    invalid_req_states = [sub_state for sub_state in req_states
                          if sub_state not in valid_req_states]
    if len(invalid_req_states) > 0:
        error_message = "The following req_states are not supported:\n" +\
            gp.sprint_var(invalid_req_states)
        BuiltIn().fail(gp.sprint_error(error_message))

    # Initialize all substate values supported by this function.
    ping = 0
    packet_loss = ''
    uptime = ''
    epoch_seconds = ''
    power = '0'
    chassis = ''
    bmc = ''
    boot_progress = ''
    host = ''

    # Get the component states.
    if 'ping' in req_states:
        # See if the OS pings.
        cmd_buf = "ping -c 1 -w 2 " + openbmc_host
        if not quiet:
            grp.rpissuing(cmd_buf)
        rc, out_buf = commands.getstatusoutput(cmd_buf)
        if rc == 0:
            ping = 1

    if 'packet_loss' in req_states:
        # See if the OS pings.
        cmd_buf = "ping -c 5 -w 5 " + openbmc_host +\
            " | egrep 'packet loss' | sed -re 's/.* ([0-9]+)%.*/\\1/g'"
        if not quiet:
            grp.rpissuing(cmd_buf)
        rc, out_buf = commands.getstatusoutput(cmd_buf)
        if rc == 0:
            packet_loss = out_buf.rstrip("\n")

    master_req_login = ['uptime', 'epoch_seconds']
    req_login = [sub_state for sub_state in req_states if sub_state in
                 master_req_login]

    must_login = (len([sub_state for sub_state in req_states
                       if sub_state in master_req_login]) > 0)

    if must_login:
        cmd_buf = ["Open Connection And Log In"]
        if not quiet:
            grp.rpissuing_keyword(cmd_buf)
        BuiltIn().run_keyword(*cmd_buf)

    if 'uptime' in req_states:
        cmd_buf = ["Execute Command", "cat /proc/uptime | cut -f 1 -d ' '",
                   "return_stderr=True", "return_rc=True"]
        if not quiet:
            grp.rpissuing_keyword(cmd_buf)
        stdout_buf, stderr_buf, rc = BuiltIn().run_keyword(*cmd_buf)
        if rc == 0 and stderr_buf == "":
            uptime = stdout_buf

    if 'epoch_seconds' in req_states:
        date_cmd_buf = "date -u +%s"
        if USE_BMC_EPOCH_TIME:
            cmd_buf = ["Execute Command", date_cmd_buf, "return_stderr=True",
                       "return_rc=True"]
            if not quiet:
                grp.rpissuing_keyword(cmd_buf)
            stdout_buf, stderr_buf, rc = BuiltIn().run_keyword(*cmd_buf)
            if rc == 0 and stderr_buf == "":
                epoch_seconds = stdout_buf.rstrip("\n")
        else:
            shell_rc, out_buf = gc.cmd_fnc_u(date_cmd_buf,
                                             quiet=1,
                                             print_output=0)
            if shell_rc == 0:
                epoch_seconds = out_buf.rstrip("\n")

    if 'power' in req_states:
        cmd_buf = ["Get Power State", "quiet=${" + str(quiet) + "}"]
        grp.rdpissuing_keyword(cmd_buf)
        power = BuiltIn().run_keyword(*cmd_buf)
    if 'chassis' in req_states:
        cmd_buf = ["Get Chassis Power State", "quiet=${" + str(quiet) + "}"]
        grp.rdpissuing_keyword(cmd_buf)
        chassis = BuiltIn().run_keyword(*cmd_buf)
        # Strip everything up to the final period.
        chassis = re.sub(r'.*\.', "", chassis)

    if 'bmc' in req_states:
        if OBMC_STATES_VERSION == 0:
            qualifier = "utils"
        else:
            qualifier = "state_manager"

        cmd_buf = [qualifier + ".Get BMC State", "quiet=${" + str(quiet) + "}"]
        # TODO: Re-enable this code once bmc status is working.
        # grp.rdpissuing_keyword(cmd_buf)
        # bmc = BuiltIn().run_keyword(*cmd_buf)

    if 'boot_progress' in req_states:
        cmd_buf = ["Get Boot Progress", "quiet=${" + str(quiet) + "}"]
        grp.rdpissuing_keyword(cmd_buf)
        boot_progress = BuiltIn().run_keyword(*cmd_buf)

    if 'host' in req_states:
        if OBMC_STATES_VERSION > 0:
            cmd_buf = ["Get Host State", "quiet=${" + str(quiet) + "}"]
            grp.rdpissuing_keyword(cmd_buf)
            host = BuiltIn().run_keyword(*cmd_buf)
            # Strip everything up to the final period.
            host = re.sub(r'.*\.', "", host)

    state = DotDict()
    for sub_state in req_states:
        if sub_state.startswith("os_"):
            # We pass "os_" requests on to get_os_state.
            continue
        cmd_buf = "state['" + sub_state + "'] = str(" + sub_state + ")"
        exec(cmd_buf)

    if os_host == "":
        # The caller has not specified an os_host so as far as we're concerned,
        # it doesn't exist.
        return state

    os_req_states = [sub_state for sub_state in req_states
                     if sub_state.startswith('os_')]

    if len(os_req_states) > 0:
        # The caller has specified an os_host and they have requested
        # information on os substates.

        # Based on the information gathered on bmc, we'll try to make a
        # determination of whether the os is even up.  We'll pass the result
        # of that assessment to get_os_state to enhance performance.
        os_up_match = DotDict()
        for sub_state in master_os_up_match:
            if sub_state in req_states:
                os_up_match[sub_state] = master_os_up_match[sub_state]
        os_up = compare_states(state, os_up_match)

        os_state = get_os_state(os_host=os_host,
                                os_username=os_username,
                                os_password=os_password,
                                req_states=os_req_states,
                                os_up=os_up,
                                quiet=quiet)
        # Append os_state dictionary to ours.
        state.update(os_state)

    return state

###############################################################################


###############################################################################
def check_state(match_state,
                invert=0,
                print_string="",
                openbmc_host="",
                openbmc_username="",
                openbmc_password="",
                os_host="",
                os_username="",
                os_password="",
                quiet=None):

    r"""
    Check that the Open BMC machine's composite state matches the specified
    state.  On success, this keyword returns the machine's composite state as a
    dictionary.

    Description of arguments:
    match_state       A dictionary whose key/value pairs are "state field"/
                      "state value".  The state value is interpreted as a
                      regular expression.  Example call from robot:
                      ${match_state}=  Create Dictionary  chassis=^On$
                      ...  bmc=^Ready$
                      ...  boot_progress=^FW Progress, Starting OS$
                      ${state}=  Check State  &{match_state}
    invert            If this flag is set, this function will succeed if the
                      states do NOT match.
    print_string      This function will print this string to the console prior
                      to getting the state.
    openbmc_host      The DNS name or IP address of the BMC.
                      This defaults to global ${OPENBMC_HOST}.
    openbmc_username  The username to be used to login to the BMC.
                      This defaults to global ${OPENBMC_USERNAME}.
    openbmc_password  The password to be used to login to the BMC.
                      This defaults to global ${OPENBMC_PASSWORD}.
    os_host           The DNS name or IP address of the operating system.
                      This defaults to global ${OS_HOST}.
    os_username       The username to be used to login to the OS.
                      This defaults to global ${OS_USERNAME}.
    os_password       The password to be used to login to the OS.
                      This defaults to global ${OS_PASSWORD}.
    quiet             Indicates whether status details should be written to the
                      console.  Defaults to either global value of ${QUIET} or
                      to 1.
    """

    quiet = grp.set_quiet_default(quiet, 1)

    grp.rprint(print_string)

    req_states = match_state.keys()
    # Initialize state.
    state = get_state(openbmc_host=openbmc_host,
                      openbmc_username=openbmc_username,
                      openbmc_password=openbmc_password,
                      os_host=os_host,
                      os_username=os_username,
                      os_password=os_password,
                      req_states=req_states,
                      quiet=quiet)
    if not quiet:
        grp.rprint_var(state)

    match = compare_states(state, match_state)

    if invert and match:
        fail_msg = "The current state of the machine matches the match" +\
                   " state:\n" + gp.sprint_varx("state", state)
        BuiltIn().fail("\n" + gp.sprint_error(fail_msg))
    elif not invert and not match:
        fail_msg = "The current state of the machine does NOT match the" +\
                   " match state:\n" +\
                   gp.sprint_varx("state", state)
        BuiltIn().fail("\n" + gp.sprint_error(fail_msg))

    return state

###############################################################################


###############################################################################
def wait_state(match_state=(),
               wait_time="1 min",
               interval="1 second",
               invert=0,
               openbmc_host="",
               openbmc_username="",
               openbmc_password="",
               os_host="",
               os_username="",
               os_password="",
               quiet=None):

    r"""
    Wait for the Open BMC machine's composite state to match the specified
    state.  On success, this keyword returns the machine's composite state as
    a dictionary.

    Description of arguments:
    match_state       A dictionary whose key/value pairs are "state field"/
                      "state value".  See check_state (above) for details.
    wait_time         The total amount of time to wait for the desired state.
                      This value may be expressed in Robot Framework's time
                      format (e.g. 1 minute, 2 min 3 s, 4.5).
    interval          The amount of time between state checks.
                      This value may be expressed in Robot Framework's time
                      format (e.g. 1 minute, 2 min 3 s, 4.5).
    invert            If this flag is set, this function will for the state of
                      the machine to cease to match the match state.
    openbmc_host      The DNS name or IP address of the BMC.
                      This defaults to global ${OPENBMC_HOST}.
    openbmc_username  The username to be used to login to the BMC.
                      This defaults to global ${OPENBMC_USERNAME}.
    openbmc_password  The password to be used to login to the BMC.
                      This defaults to global ${OPENBMC_PASSWORD}.
    os_host           The DNS name or IP address of the operating system.
                      This defaults to global ${OS_HOST}.
    os_username       The username to be used to login to the OS.
                      This defaults to global ${OS_USERNAME}.
    os_password       The password to be used to login to the OS.
                      This defaults to global ${OS_PASSWORD}.
    quiet             Indicates whether status details should be written to the
                      console.  Defaults to either global value of ${QUIET} or
                      to 1.
    """

    quiet = grp.set_quiet_default(quiet, 1)

    if not quiet:
        if invert:
            alt_text = "cease to "
        else:
            alt_text = ""
        grp.rprint_timen("Checking every " + str(interval) + " for up to " +
                         str(wait_time) + " for the state of the machine to " +
                         alt_text + "match the state shown below.")
        grp.rprint_var(match_state)

    if quiet:
        print_string = ""
    else:
        print_string = "#"

    debug = int(BuiltIn().get_variable_value("${debug}", "0"))
    if debug:
        # In debug we print state so no need to print the "#".
        print_string = ""
    check_state_quiet = 1 - debug
    cmd_buf = ["Check State", match_state, "invert=${" + str(invert) + "}",
               "print_string=" + print_string, "openbmc_host=" + openbmc_host,
               "openbmc_username=" + openbmc_username,
               "openbmc_password=" + openbmc_password, "os_host=" + os_host,
               "os_username=" + os_username, "os_password=" + os_password,
               "quiet=${" + str(check_state_quiet) + "}"]
    grp.rdpissuing_keyword(cmd_buf)
    state = BuiltIn().wait_until_keyword_succeeds(wait_time, interval,
                                                  *cmd_buf)
    if not quiet:
        grp.rprintn()
        if invert:
            grp.rprint_timen("The states no longer match:")
        else:
            grp.rprint_timen("The states match:")
        grp.rprint_var(state)

    return state

###############################################################################


###############################################################################
def wait_for_comm_cycle(start_boot_seconds):

    r"""
    Wait for communications to the BMC to stop working and then resume working.
    This function is useful when you have initiated some kind of reboot.

    Description of arguments:
    start_boot_seconds  The time that the boot test started.  The format is the
                        epoch time in seconds, i.e. the number of seconds since
                        1970-01-01 00:00:00 UTC.  This value should be obtained
                        from the BMC so that it is not dependent on any kind of
                        synchronization between this machine and the target BMC
                        This will allow this program to work correctly even in
                        a simulated environment.  This value should be obtained
                        by the caller prior to initiating a reboot.  It can be
                        obtained as follows:
                        state = st.get_state(req_states=['epoch_seconds'])
    """

    # Validate parms.
    error_message = gv.svalid_integer(start_boot_seconds,
                                      var_name="start_boot_seconds")
    if error_message != "":
        BuiltIn().fail(gp.sprint_error(error_message))

    match_state = anchor_state(DotDict([('packet_loss', '100')]))
    # Wait for 100% packet loss trying to ping machine.
    wait_state(match_state, wait_time="3 mins", interval="0 seconds")

    match_state['packet_loss'] = '^0$'
    # Wait for 0% packet loss trying to ping machine.
    wait_state(match_state, wait_time="4 mins", interval="0 seconds")

    # Get the uptime and epoch seconds for comparisons.  We want to be sure
    # that the uptime is less than the elapsed boot time.  Further proof that
    # a reboot has indeed occurred (vs random network instability giving a
    # false positive.
    state = get_state(req_states=['uptime', 'epoch_seconds'])

    elapsed_boot_time = int(state['epoch_seconds']) - start_boot_seconds
    grp.rprint_var(elapsed_boot_time)
    if int(float(state['uptime'])) < elapsed_boot_time:
        uptime = state['uptime']
        grp.rprint_var(uptime)
        grp.rprint_timen("The uptime is less than the elapsed boot time," +
                         " as expected.")
    else:
        error_message = "The uptime is greater than the elapsed boot time," +\
                        " which is unexpected:\n" +\
                        gp.sprint_var(start_boot_seconds) +\
                        gp.sprint_var(state)
        BuiltIn().fail(gp.sprint_error(error_message))

    grp.rprint_timen("Verifying that REST API interface is working.")
    match_state = DotDict([('chassis', '.*')])
    state = wait_state(match_state, wait_time="5 mins", interval="2 seconds")

###############################################################################
