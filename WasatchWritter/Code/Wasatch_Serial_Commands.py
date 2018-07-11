#
# File: WasatchInterface_MicroscopeSettings
# ------------------------------
# Author: Erick Blankenberg
# Date: 5/12/2018
#
# Description:
#   These methods return strings to be
#   sent directly to the Wasatch via serial.
#

#---------------------- Included Libraries -------------------------------------

from Wasatch_Conversions import *
from Wasatch_Units import *

#--------------------------- Constants -----------------------------------------

MOTOR_IDENTIFIERS = {'q', 'p', 'i', 'h'}

#--------------------- Function Definitions ------------------------------------

# ------- Galvo Commands:

#
# Description:
#   Retrieves the version number of the Wasatch
#
# Response:
#    Always "Ver:#.##\r\nA\n".
#
# Returns:
#   Serial printable command string.
#
def WCommand_Version():
    return "ver"

#
# Description:
#   Resets the Wasatch.
#
# Response:
#   None.
#
# Returns:
#   Serial printable command string.
#
def WCommand_Reset():
    return "reset"

#
# Description:
#   Puts the Wasatch into update mode.
#
# Response:
#   Always 'A'.
#
# Returns:
#   Serial printable command string.
#
def WCommand_FirmwareUpdate():
    return "dfu"

#
# Description:
#   Pings the Wasatch.
#
# Response:
#   Always 'A'.
#
# Returns:
#   Serial printable command string.
#
def WCommand_Ping():
    return "ping"

#
# Description:
#   Sets the voltage control for the liquid lens
#   focus (?).
#
# Parameters:
#   'value' (Integer) (optional) Range from 0 - 4095
#
# Response:
#   With parameters: 'A'
#   No parameters:   Current setting
#
# Returns:
#   Serial printable command string.
#
def WCommand_Focus(value = 'default_value'):
    if(value == 'default_value'):
        return "focus"
    if(isinstance(value, int) and (value > 4095 or value < 0)):
        raise ValueError("Serial Error: Requested Wasatch focus value %s is invalid." % (value))
    else:
        return "focus %d" % (value)

#
# Description:
#   Sets the voltage control for the liquid lens foci (?).
#
# Parameters:
#   'value' (integer) Range from 0-255
#
# Response:
#   With parameters: 'A'
#   No parameters:   Current setting
#
# Returns:
#   Serial printable command string.
#
def WCommand_Foci(value = 'default_value'):
    if(value == 'default_value'):
        return "foci"
    if(isinstance(value, int) and (value > 255 or value < 0)):
        raise ValueError("Serial Error: Requested Wasatch foci value %s is invalid." % (value))
    else:
        return "foci %d" % (value)

#
# Description:
#   Turns the output on and off (?).
#
# Parameters:
#   'output' (Integer) The output number, either 1 or 2.
#   'value'  (Integer) (optional) 0 for off, all other numbers on. Leave blank
#                                 to read the current settings.
#
# Response:
#   With parameters: 'A'
#   No parameters:   Current setting of the output.
#
# Returns:
#   Serial printable command string.
#
def WCommand_Toggle(output, value = 'default_value'):
    if(isinstance(output, int) and (output == 1 or output == 2)):
        if(value == 'default_value'):
            return "out%d" % (servo)
        if(isinstance(value, int) and (value >= 0)):
            return "out%d %d" % (servo, value)
        else:
            raise ValueError("Serial Error: Requested Wasatch motor state %s is invalid." % (value))
    else:
        raise ValueError("Serial Error: Requested Wasatch motor %s is invalid." % (output))

#
# Descriptions:
#   Reads the EEPROM of the Wasatch at the memory
#   location 'address'
#
# Parameters:
#   'address' (Integer) The address to read
#
# Response:
#   Returns a page of hexadecimal from the EEPROM
#   at that location
#
# Returns:
#   Serial printable command string.
#
def WCommand_ReadEEPROM(address):
    if(isinstance(address, int)):
        return "eer %d" % (address)
    else:
        raise ValueError("Serial Error: Requested Wasatch EEPROM address %s is invalid." % (address))

#
# Description:
#   Writes a byte to the given location.
#
# Parameters:
#   'address' (Integer) The location in EEPROM to write to (integer)
#   'value'   (Integer) The value to write in hexadecimal
#
# Response:
#   Always: 'A'
#
# Returns:
#   Serial printable command string.
#
def WCommand_WriteEEPROM(address, value):
    if(isinstance(address, int) and isInstance(value, int) and value <= 255):
        return "eew %d %s" % (address, hex(value))
    else:
        raise ValueError("Serial Error: Requested Wasatch EEPROM write location %s value %s is invalid." % (address, value))

# ------- Sweep Commands:

#
# Description:
#   Sets the number of pulse triggers per sweep of the camera.
#   Reducing this value will reduce the duration of a single sweep.
#
# Parameters:
#   'numScans' (Integer) (optional) Number of data points per sweep.
#                                   Range is (2-65535), default is 1000
#                                   Leave blank to return current setting.
#
# Response:
#   With parameters: "ok.\n"
#   Without parameters: Returns current value
#
# Returns:
#   Serial printable command string.
#
def WCommand_ScanAScans(numScans = "default_value"):
    if(numScans != "default_value"):
        numScans = int(numScans)
        if(isinstance(numScans, int)):
            return "a_scans %d" % (numScans)
        else:
            raise ValueError("Serial Error: Requested Wasatch triggers per minor sweep %s is invalid." % (numScans))
    return "a_scans"

#
# Description:
#   Sets the number of minor sweeps (primary sweeps) per major sweep (slower
#   orthogonal sweep for volume).
#
# Parameters:
#   'numScans' (Integer) (optional) number of minor sweeps per orthogonal sweep.
#                                   Value is in range from [0, 65534] multiple
#                                   of 2, default is 0. Leave blank to return
#                                   current setting.
#
# Response:
#   With parameters: "ok.\n"
#   Without parameters: returns current setting
#
# Returns:
#   Serial printable command string.
#
def WCommand_ScanBScans(numScans = "default_value"):
    if numScans != "default_value":
        numScans = int(numScans)
        if(isinstance(numScans, int) and (numScans % 2 == 0) and (numScans >= 0) and (numScans <= 65534)):
            return "b_scans %d" % (numScans)
        else:
            raise ValueError("Serial Error: Requested Wasatch minor sweeps per major sweep %s is invalid." % (numScans))
    return "b_scans"

#
# Description:
#   Sets the delay between camera pulses in microseconds.
#
# Parameters:
#   'duration' (Float) (If specified unitRegistry units [Time], otherwise
#              assumed to be in seconds) (optional) Delay between camera pulses.
#              Range in microseconds is [3,65535], default is 50. Leave blank
#              to return current settings.
#
# Response:
#   With settings: "ok.\n"
#   Without parameters: returns current setting
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanPulseDelay(duration = "default_value"):
    if(duration != "default_value"):
        microseconds = int(WConvert_ToSeconds(duration).to(unitRegistry.microseconds).magnitude))
        if(isinstance(microseconds, int) and (microseconds >= 3) and (microseconds <= 65535)):
            return "delay %d" % (microseconds)
        else:
            raise ValueError("Serial Error: Requested Wasatch pulse delay %s is invalid." % (duration))
    return "delay"

#
# Description:
#   Sets the duration of a camera pulse in microseconds, if set to zero
#   no pulses occur. Will return current settings without parameters.
#
# Parameters:
#   'duration' (Float) (If specified unitRegistry units [Time], otherwise
#              assumed to be in seconds) (optional) Delay between camera pulses.
#              Range in microseconds is [0,65535], default is 5. Leave blank
#              to return current settings.
#
# Response:
#   With parameters 'ok.\n'
#   Without parameters returns current setting.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanPulseDuration(duration = "default_value"):
    if(duration != "default_value"):
        microseconds = round(WConvert_ToSeconds(duration).to(unitRegistry.microsecond).magnitude)
        if (isinstance(microseconds, int) and (microseconds >= 0) and (microseconds <= 605535)):
            return "pulse %d" % (microseconds)
        else:
            raise ValueError("Serial Error: Requested Wasatch pulse duration %s is invalid." % (duration))
    return "pulse"

#
# Description:
#   Sets the duration of a non-triggering return pulse and delay combined.
#
# Parameters:
#   'duration' (Float) (If specified unitRegistry units [Time], otherwise
#              assumed to be in seconds) (optional) The duration of a return period.
#              Range is [0, 255], default is 7. Leave blank to return current settings.
#
# Response:
#   With parameters 'ok.\n'
#   Without parameters returns current setting.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanReturnSetDuration(duration = "default_value"):
    if(duration != "default_value"):
        microseconds = round(WConvert_Seconds(duration).to(unitRegistry.microsecond).magnitude)
        if (isinstance(microseconds, int) and (microseconds >= 0) and (microseconds <= 255)):
            return "t_ret %d" % (microseconds)
        else:
            raise ValueError("Serial Error: Requested Wasatch delay period duration %s is invalid." % (duration))
    return "t_ret"

#
# Description:
#   Scales the return path time, the return path has the same number
#   of samples as the outbound path, the return counter is incremented
#   by multiples of this value, effectively making it 'factor' times faster.
#
# Parameters:
#   'factor' (Integer) (optional) Integer multiple for the return counter. Range is [0, 65535],
#                                 default is 1. Leave blank to return current settings.
#
# Response:
#   With parameters 'ok.\n'
#   Without parameters returns current setting.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanReturnClockDivider(factor = "default_value"):
    if(factor != "default_value"):
        if (isinstance(factor, int) and (factor >= 0) and (factor <= 605535)):
            return "A_div %d" % (factor))
        else:
            raise ValueError("Serial Error: Requested Wasatch return clock divider %s is invalid." % (factor))
    return "A_div"

#
# Description:
#   Adjusts phase relationship between mirror movement and triggering.
#
# Parameters:
#   'offset' (Integer) (optional) Phase shift (?) range is [0, 65535], default is 100.
#                                 Leave blank to return current settings. Currently assumed
#                                 to be triggering count offset.
#
# Response:
#   With parameters 'ok.\n'
#   Without parameters returns current setting.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanPhaseShift(offset = "default_value"):
    if(offset != "default_value"):
        if (isinstance(offset, int) and (offset >= 0) and (offset <= 605535)):
            return "Phase %d" % (offset)
        else:
            raise ValueError("Serial Error: Requested Wasatch triggering phase shift %s is invalid." % (offset))
    return "Phase"

#
# Description:
#   Enables triggers on the return sweep, if set to one then
#   triggers occur, otherwise no triggers will occur on the return sweep.
#
# Parameters:
#   'enable' (Bool) (optional) True if triggers should be enabled for the return scan,
#                              false otherwise, disabled by default. Leave blank
#                              to return current setting.
#
# Response:
#   With parameters 'ok.\n'
#   Without parameters returns current setting.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanReturnTrigger(enable = "default_value"):
    if(enable != "default_value"):
        if (isinstance(enable, bool)):
            value = 0
            if enable
                value = 1
            return "trigger %d" % (value)
        else:
            raise ValueError("Serial Error: Requested Wasatch trigger value %s is invalid." % (enable))
    return "trigger"

#
# Description:
#   Sets triggerless pulses between a scans.
#
# Parameters:
#   'delayCount' (Integer) (optional) Number of triggerless pulses between a scans
#                                     for stabilization. Range is [0, 65535],
#                                     default is 0. Leave blank to return
#                                     current settings.
# Response:
#   With parameters 'ok.\n'
#   Without parameters returns current setting.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanATriggerGap(delayCount = "default_value"):
    if(delayCount != "default_value"):
        if (isinstance(delayCount, int) and (delayCount >= 0) and (delayCount <= 605535)):
            return "a_hold %d" % (delayCount)
        else:
            raise ValueError("Serial Error: Requested Wasatch triggerless pulses per a scan %s is invalid." % (delayCount))
    return "a_hold"

#
# Description:
#   Sets triggerless pulses between b scans.
#
# Parameters:
#   'delayCount' (Integer) (optional) Number of triggerless pulses between b scans
#                                     for stabilization. Range is [0, 65535],
#                                     default is 0. Leave blank to return
#                                     current settings.
# Response:
#   With parameters 'ok.\n'
#   Without parameters returns current setting.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanBTriggerGap(delayCount = "default_value"):
    if(delayCount != "default_value"):
        if (isinstance(delayCount, int) and (delayCount >= 0) and (delayCount <= 605535)):
            return "b_hold %d" % (delayCount)
        else:
            raise ValueError("Serial Error: Requested Wasatch triggerless pulses per b scan %s is invalid." % (delayCount))
    return "b_hold"

#
# Description:
#   Sets the delay before the first strigger.
#
# Parameters:
#   'delay' (Integer) Delay before first trigger (?). Units currently not known.
#
def WCommand_ScanTriggerDelay(delay = "default_value"):
    if(delay != "default_value"):
        if (isinstance(delay, int) and (delayCount >= 0) and (delayCount <= 605535)):
            return "trdelay %d" % (delayCount)
        else:
            raise ValueError("Serial Error: Requested Wasatch trigger delay %s is invalid." % (delay))
    return "trdelay"

#
# Description:
#   Sets whether the trigger delay is added to the
#   beginning and end of the sweep. Will return current settings
#   without parameters.
#
# Parameters:
#   'enable' (Integer) Set to 1 to enable the trigger, 0 to disable.
#                      Leave blank to return the current setting.
#
# Response:
#   With parameters 'ok.\n'
#   Without parameters returns current setting.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanTriggerDelayEnable(enable = "default_value"):
    if(enable != "default_value"):
        if isinstance(enable, int) and (enable == 0 or enable == 1):
            return "trdmode %d" % (enable)
        else:
            raise ValueError("Serial Error: Requested Wasatch trigger delay enable %s is invalid." % (enable))
    return "trdmode"

#
# Description:
#   Configures the X ramp scanning parameters for the Wasatch
#
# Parameters:
#   'startX'   (Float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) Starting X position of the rectangle.
#
#   'stopX'    (Float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) End X position of the rectangle.
#
#   'bRepeats' (Integer) The number of times to repeat
#                        each scan line, defaults to 1
#
#   'flags'    (string) (variable number of args) (optional) Flags for the line.
#                       -> 'wasatchUnits' Arguments are interpreted directly as wasatch units
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanXRamp(startX, stopX, bRepeats = 1, *flags):
    xStartWU = CENTER_X - WConvert_XToWasatchUnits(startX, flags)
    xStopWU = CENTER_X + WConvert_XToWasatchUnits(stopX, flags)
    if(MIN_X <= xStartWU <= MAX_X and MIN_X <= xStopWU <= MAX_X and isinstance(bRepeats, int)):
        return "xramp %d %d %d" % (xStartWU, xStopWU, bRepeats)
    else:
        raise ValueError("Serial Error: Requested Wasatch coordinates are invalid.")

#
# Description:
#   Configures the Y ramp scanning parameters for the Wasatch
#
# Parameters:
#   'startY'   (Float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) Starting Y position of the rectangle.
#
#   'stopY'    (Float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) End Y position of the rectangle.
#
#   'bRepeats' (Integer) The number of times to repeat
#                        each scan line, defaults to 1
#
#   'flags'    (string) (variable number of args) (optional) Flags for the line.
#                       -> 'wasatchUnits' Arguments are interpreted directly as wasatch units
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanYRamp(startY, stopY, bRepeats = 1, *flags):
    yStartWU = CENTER_Y - WConvert_YToWasatchUnits(startY, flags)
    yStopWU = CENTER_Y + WConvert_YToWasatchUnits(stopY, flags)
    if(MIN_Y <= yStartWU <= MAX_Y and MIN_Y <= yStopWU <= MAX_Y and isinstance(bRepeats, int)):
        return "yramp %d %d %d" % (yStartWU, yStopWU, bRepeats)
    else:
        raise ValueError("Serial Error: Requested Wasatch coordinates are invalid.")

#
# Description:
#   Configures the Wasatch to scan a square region
#   from the two specified corners.
#   All measurements are distance from the center.
#
# Parameters:
#   'startY'   (Float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) Starting Y position of the rectangle.
#
#   'stopY'    (Float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) End Y position of the rectangle.
#
#   'bRepeats' (Integer) The number of times to repeat each scan line, defaults to 1
#
#   'flags'    (string) (variable number of args) (optional) Flags for the line.
#                       -> 'wasatchUnits' Arguments are interpreted directly as wasatch units
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanXYRamp(startX, startY, stopX, stopY, bRepeats = 1):
    xStartWU = CENTER_X - WConvert_XToWasatchUnits(startX, flags)
    yStartWU = CENTER_Y - WConvert_YToWasatchUnits(startY, flags)
    xStopWU = CENTER_X + WConvert_XToWasatchUnits(stopX, flags)
    yStopWU = CENTER_Y + WConvert_YToWasatchUnits(stopY, flags)
    if(MIN_X <= xStartWU <= MAX_X ,MIN_Y <= yStartWU <= MAX_Y, MIN_X <= xStopWU <= MAX_X, MIN_Y <= yStopWU <= MAX_Y, isinstance(bRepeats, int)):
        return "xy_ramp %d %d %d %d %d" % (xStartWU, xStopWU, yStartWU, yStopWU, bRepeats)
    raise ValueError("Serial Error: Requested Wasatch coordinates are invalid.")

#
# Description: # TODO Wasatch_Serial_Commands: Revisit polar ramp w/ unit conversion change
#   Draws a polar ramp (concentric circular scan).
#   Note: Set the number of scanned points per circle with A_scans, set
#   the number of concentric cirles with B_scans.
#
# Parameters:
#   'centerPoint'    (Tuple of Floats) ([Length]) The center of the scan of the form (x, y)
#   'radius'         (Float) ([Length])           The radius of the scanned region
#   'ringRepeats'    (Integer) (optional)         The number of times to repeat each layer
#                                                 of the scan, defaults to 1.
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanPolar(centerPoint, radius, ringRepeats = 1):
    if(isInstance(centerPoint[0].magnitude, float) and isInstance(centerPoint[1].magnitude, float) and isInstance(radius, float) and isInstance(ringRepeats, int)):
        convertedCenter = WConvert_PointToCenteredInput(centerPoint)
        return "pramp %d %d %d %d" % (convertedCenter[0], convertedCenter[1], WConvert_PointToCenteredInput(radius, 0)[0], ringRepeats) #TODO Serial_Commands: Single element conversion
    else:
        raise ValueError("Serial Error: Polar ramp with center point %s %s, radius %s, and repeats %s, is invalid." % (centerPoint[0], centerPoint[1], radius, ringRepeats))

#
# Description: # TODO Serial_Commands: revisit spiral
#   Draws an archimedes spiral. You set the number of samples per spiral with the
#
# Parameters:
#   'centerPoint'    (Tuple of Floats) ([Length]) The center of the scan of the form (x, y)
#   'radius'         (Float) ([Length])           The radius of the scanned region
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanSpiral(centerPoint, radius):
    if(isInstance(centerPoint[0].magnitude, float) and isInstance(centerPoint[1].magnitude, float) and isInstance(radius, float)):
        convertedCenter = WConvert_PointToCenteredInput(centerPoint)
        return "pramp %d %d %d %d" % (convertedCenter[0], convertedCenter[1], WConvert_PointToCenteredInput(radius, 0)[0]) #TODO Serial_Commands: Single element conversion
    else:
        raise ValueError("Serial Error: Polar ramp with center point %s %s, radius %s, and repeats %s, is invalid." % (centerPoint[0], centerPoint[1], radius, ringRepeats))

#
# Description:
#   Initiates a scan that repeats for 'count' times. If 'count'
#   is negative or if there are no arguments, scans indefinitely.
#   In vector mode, this is the number of single b-scans, in raster
#   mode these are c-scans.
#
# Parameters:
#   'count' (int) Number of scans, ranges from +- 2,147,483,648
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanNTimes(count = 0):
    if(isinstance(count, int)):
        return "scan %d" % (count)
    else:
        raise ValueError("Serial Error: Requested Wasatch scan count is invalid.")

#
# Description:
#   Same as above but without triggers.
#
# Parameters:
#   'count' (int) Number of scans, ranges from +- 2,147,483,648
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanNTimesNoTrigger(count = 0):
    if(isinstance(count, int)):
        return "ntscan %d" % (count)
    else:
        raise ValueError("Serial Error: Requested Wasatch non-triggering scan count is invalid.")

#
# Description:
#   Stops the current Wasatch scan at the end of the
#   current minor scan and turns off the mirrors.
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_ScanStop():
    return "stop"

# ------- Motor Commands:

#
# Description:
#   Sets the top speed of the given motor, not currently
#   implimented in the Wasatch.
#
# Parameters:
#   'motorIdentifier' (String or Char)      Value is 'q', 'p', 'i', or 'h'.
#                                           Sets the target motor.
#   'value'           (Integer) (optional)  Top speed for motor, units
#                                           and bounds currently unknown.
#
# Response:
#   Will return 'A' with no parameters
#   or with the current setting otherwise.
#   This is not currently implimented.
#
# Returns:
#   String to be directly entered into the Wasatch terminal.
#
def WCommand_MotorSetTopSpeed(motorIdentifier, value = "default_value"):
    if(motorIdentifier in MOTOR_IDENTIFIERS):
        if(value != "default_value"):
            return "mmset %s %d" % (motorIdentifier, value)
        else:
            return "mmset %s" % (motorIdentifier)
    else:
        ValueError("Serial Error: Requested Wasatch motor top speed for %s with value %s is invalid." % (motorIdentifier, value))

#
# Description:
#   Sets the top acceleration of the given motor, not currently
#   implimented in the Wasatch.
#
# Parameters:
#   'motorIdentifier' (String or Char)      Value is 'q', 'p', 'i', or 'h'.
#                                           Sets the target motor.
#   'value'           (Integer) (optional)  Top acceleration for motor, units
#                                           and bounds currently unknown.
#
# Response:
#   Will return 'A' with parameters
#   or with the current setting otherwise.
#   This is not currently implimented.
#
# Returns:
#   String to be directly entered into the Wasatch terminal.
#
def WCommand_MotorSetTopAcceleration(motorIdentifier, value = "default_value"):
    if(motorIdentifier in MOTOR_IDENTIFIERS):
        if(value != "default_value"):
            return "maset %s %d" % (motorIdentifier, value)
        else:
            return "maset %s" % (motorIdentifier)
    else:
        ValueError("Serial Error: Requested Wasatch motor top acceleration for %s with value %s is invalid." % (motorIdentifier, value))

#
# Description:
#   Sends the motor to the relative location given in value.
#
# Parameters:
#   'motorIdentifier' (String or Char)   Value is 'q', 'p', 'i', or 'h'.
#                                        Sets the target motor.
#   'value'           (float) ([Length]) Location to send the motor to
#                                        from current position.
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be directly entered into the Wasatch serial terminal.
#
def WCommand_MotorGoAbsolute(motorIdentifier, value):
    if(motorIdentifier in MOTOR_IDENTIFIERS and isinstance(value.magnitude, float)):
        return "mgr %s %d" % (motorIdentifier, WConvert_PointToCenteredInput(value))
    else:
        ValueError("Serial Error: Requested Wasatch motor travel distance %s is invalid." % (motorIdentifier))

#
# Description:
#   Sends the motor to the absolute location given in value.
#
# Parameters:
#   'motorIdentifier' (String or Char)   Value is 'q', 'p', 'i', or 'h'.
#                                        Sets the target motor.
#   'value'           (float) ([Length]) Location to send the motor to.
#
# Response:
#   Always 'A'
#
# Returns:
#   String to be directly entered into the Wasatch serial terminal.
#
def WCommand_MotorGoAbsolute(motorIdentifier, value):
    if(motorIdentifier in MOTOR_IDENTIFIERS and isinstance(value.magnitude, float)):
        return "mg2 %s %d" % (motorIdentifier, WConvert_PointToCenteredInput(value))
    else:
        ValueError("Serial Error: Requested Wasatch motor travel distance %s is invalid." % (motorIdentifier))

#
# Description:
#   Sends the target motor to the home location.
#   Note: Currently disabled in the firmware.
#
# Parameters:
#   'motorIdentifier' (String or Char) (optional) Value is 'q', 'p', 'i', or 'h'.
#                                                 Sets the target motor. If not
#                                                 specified all are homed.
#
# Response:
#   Always 'A'.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_MotorHome(motorIdentifier = 'a'):
    if(motorIdentifier != 'a'):
        if(motorIdentifier in MOTOR_IDENTIFIERS):
            return "mgh %s" % (motorIdentifier)
        else:
            ValueError("Serial Error: Requested Wasatch motor to home %s is invalid." % (motorIdentifier))
    return "mgh a"

#
# Description:
#   Sets the motor direction for the given motor.
#
# Parameters:
#   'motorIdentifier' (String or Char)  Value is 'q', 'p', 'i', or 'h'.
#                                       Sets the target motor.
#
#   'forwards'        (Bool) (optional) Sets the motor forward if true (defualt),
#                                          backwards otherwise.
#
# Response:
#   Always 'A'.
#
# Returns:
#   String to be directly entered into the Wasatch serial terminal.
#
def WCommand_MotorDirection(motorIdentifier, forwards = true):
    if(motorIdentifier in MOTOR_IDENTIFIERS and isinstance(forwards, bool)):
        value = 1
        if forwards
            value = 0
        return "mgd %s %d" % (motorIdentifier, value)
    ValueError("Serial Error: Requested Wasatch motor %s or direction %s is invalid." % (motorIdentifier, forwards))

#
# Description:
#   Stops the given motor.
#
# Parameters:
#   'motorIdentifier' (String or Char) (optional) Value is 'q', 'p', 'i', or 'h', motor to stop.
#                                                 If left blank, will use 'a' to stop all motors.
#
# Response:
#   Always responds with 'A'.
#
# Returns:
#   String to enter directly into the Wasatch terminal.
#
def WCommand_MotorStop(motorIdentifier = 'a'):
    if(motorIdentifier != 'a'):
        if(motorIdentifier in MOTOR_IDENTIFIERS):
            return "mstop %s" % (motorIdentifier)
        else:
            ValueError("Serial Error: Requested Wasatch motor halt for %s is invalid." % (motorIdentifier))
    return "mstop a"

# Description:
#   Returns the speed and destination for each motor.
#
# Response:
#   Returns the motor parameters, also returns 'A'.
#
# Returns:
#   String to be entered directly into the Wasatch serial terminal.
#
def WCommand_MotorGetInfo():
    return "minfo"

#
# Description:
#   Returns whether the motors are currently in the home positon.
#
# Parameters:
#   'motorIdentifier' (String or Char) (optional) Value is 'q', 'p', 'i', or 'h', motor to query if home
#                                                 If left blank, will use 'a' which will return a byte
#                                                 whose bits are set to one if the motor is home, false otherwise.
#
# Response:
#   Always responds with 'A', but also responds with 1 if the motor is home, 0 otherwise.
#
# Returns:
#   String to enter directly into the Wasatch terminal.
#
def WCommand_MotorIsHome(motorIdentifier = 'a'):
    if(motorIdentifier != 'a'):
        if(motorIdentifier in MOTOR_IDENTIFIERS):
            return "mih %s" % (motorIdentifier)
        else:
            ValueError("Serial Error: Requested Wasatch motor home status for %s is invalid." % (motorIdentifier))
    return "mih a"
