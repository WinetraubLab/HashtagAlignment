#
# File: WasatchInterface_MicroscopeSettings
# ------------------------------
# Author: Erick Blankenberg, based off of work from Edwin
# Date: 5/12/2018
#
# Description:
#
# These methods convert user inputs in conventional units
# to units that the microscope uses for serial interpretation.
#

#----------------------- Imported Libraries -----------------------------------

import math

from Wasatch_Units import *

#---------------------------- Constants ---------------------------------------

# Microseconds of dwelling time to fully bleach one mm long section w/ standard profile
USFORMM = 3000 * (unitRegistry.microsecond / unitRegistry.millimeter)

# Wasatch reach seems to be roughly 10mm in each direction
# Values calibrated 7/13/2017
WUPERMM_Y = 2207 / unitRegistry.millimeter
WUPERMM_X = 2257 / unitRegistry.millimeter
MIN_Y = 5000
MAX_Y = 25000
MIN_X = 5000
MAX_X = 25000
CENTER_X = (MAX_X + MIN_X) / 2
CENTER_Y = (MAX_Y + MIN_Y) / 2

# Note that actual total exposure times are determined from USFORMM, these
# are just preferences but should not effect the total amount of energy
# recieved by the sample.
PULSEPERIOD = 100 * unitRegistry.microsecond # Duration of a delay-pulse pair
PULSESPERSWEEP = 100 # Number of pulses per sweep of the scanner
DUTY_CYCLE = 0.75 # Percentage of on time for pulses, this is the assumed duty cycle in USFORMM

# ---------------------- Function Definitions ---------------------------------

#
# Description:
#   Converts the given value to Wasatch units using the calibration
#   for the X axis.
#
# Parameters:
#   'inputX' (float) (If unitRegistry units specified [Length],
#            unspecified assumes mm, if flag 'wasatchUnits' used does not
#            alter the input argument) Length along X axis to convert.
#
# Returns:
#   The function returns a floating point quantity of Wasatch units.
#
def WConvert_XToWasatchUnits(inputX, *flags):
    if("wasatchUnits" in flags):
        return inputX
    else:
        if not isinstance(inputX, pint.quantity._Quantity): # Default behavior is to assume millimeters if unspecified
            inputX = float(inputX)
            inputX *= unitRegistry.millimeter
        return (inputX.to(unitRegistry.millimeter) * WUPERMM_X)

#
# Description:
#   Converts the given value to Wasatch units using the calibration
#   for the Y axis.
#
# Parameters:
#   'inputX' (float) (If unitRegistry units specified [Length],
#            unspecified assumes mm, if flag 'wasatchUnits' used does not
#            alter the input argument) Length along Y axis to convert.
#
# Returns:
#   The function returns a floating point quantity of Wasatch units.
#
def WConvert_YToWasatchUnits(inputY, *flags):
    if("wasatchUnits" in flags):
        return inputY
    else:
        if not isinstance(inputY, pint.quantity._Quantity): # Default behavior is to assume millimeters if unspecified
            inputY = float(inputY)
            inputY *= unitRegistry.millimeter
        return (inputY.to(unitRegistry.millimeter) * WUPERMM_Y)

#
# Description:
#   Utility function that converts the given duration to seconds.
#
# Parameters:
#   'inputDuration' (float) (If unitRegistry units specified [Time],
#                    unspecified assumes seconds)
#
# Returns:
#   The function returns a floating point quantity of Wasatch units.
#
def WConvert_ToSeconds(inputDuration):
    if not isinstance(inputDuration, pint.quantity._Quantity):
        inputDuration = float(inputDuration)
        inputDuration *= unitRegistry.seconds
    return inputDuration.to(unitRegistry.seconds)



#
# Description:
#   Returns the number of scans from the required duration
#
# Parameters:
#   'duration'       (float) (If unitRegistry units specified [Time],
#                    unspecified assumes seconds) Desired line duration.
#
#   'pulsePeriod'    (float) (If unitRegistry units specified [Time],
#                    unspecified assumes seconds) Period of a single
#                    camera pulse.
#
#   'pulsesPerSweep' (int)   Number of pulses in a primary scan.
#
# Returns:
#   Integer number of scans required.
#
def WConvert_NumScansFromSecs(duration, pulsePeriod = PULSEPERIOD, pulseCount = PULSESPERSWEEP):
    duration = WConvert_ToSeconds(duration)
    return int(math.ceil((WConvert_ToSeconds(duration)) / (WConvert_ToSeconds(PULSEPERIOD) * PULSESPERSWEEP)))

#
# Determines the number of complete scans required to achieve
# the desired exposure percentage with the given duty cycle,
# and period of the pulse.
#
def WConvert_NumScans(distance, exposurePercentage, dutyCycle = DUTY_CYCLE, pulsePeriod = PULSEPERIOD, pulsesPerSweep = PULSESPERSWEEP):
    # Calculates scans for full exposure
    normalizedDutyCycle = (dutyCycle / DUTY_CYCLE)
    normalRequiredTime = (USFORMM * distance) / normalizedDutyCycle
    normalRequiredPasses = normalRequiredTime / (2 * pulsesPerSweep * pulsePeriod)
    # Applies exposure percentage
    nTimes = round((exposurePercentage * normalRequiredPasses))
    return nTimes

#
# Description:
#   Calculates duration of pulse for the given duty cycle.
#
# Parameters:
#   'dutyCycle' (float) Proportion of time on (1.0 maximum)
#
# Returns:
#   Returns the pulse length in microseconds.
#
def WConvert_PulseDuration(dutyCycle = DUTY_CYCLE):
    return round(dutyCycle * PULSEPERIOD)

#
# Description:
#   Calculates delay between pulses for the given duty cycle.
#
# Returns:
#   The delay between pulses in pint compatable microseconds.
#
def WConvert_PulseDelay(dutyCycle = DUTY_CYCLE):
    return round((1 - dutyCycle) * PULSEPERIOD)

#
# Returns the number of triggers per sweep
#
def WConvert_PulsesPerSweep():
    return PULSESPERSWEEP
