# TODO: Conversions: Bleachpercentage overhaul, use default values for conversions
# COMBAK Conversions: Standardize documentation. Add more conversions.
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

# Borrowed from Edwin's code, Wasatch units seem to be roughly 2093 per mm
# Udate: 6/27/2018, found that 50
MIN_Y = 3492.0
MAX_Y = 24418.0 # Originally 24418, adjusted by 0.93
MIN_X = 5081.0
MAX_X = 26032.0 # Originally 26032, adjusted by 0.93
# Wasatch reach seems to be 10mm in each direction (calibrated for this)
MM_Y = 10.0 * unitRegistry.millimeter
MM_X = 10.0 * unitRegistry.millimeter

# Note that actual total exposure times are determined from USFORMM, these
# are just preferences but should not effect the total amount of energy
# recieved by the sample.
PULSEPERIOD = 100 * unitRegistry.microsecond # Duration of a delay-pulse pair
PULSESPERSWEEP = 100 # Number of pulses per sweep of the scanner
DUTY_CYCLE = 0.75 # Percentage of on time for pulses, this is the assumed duty cycle in USFORMM

# ---------------------- Function Definitions ---------------------------------

#
# Description:
#   Converts desired point to a point in wasatch units. Good for about 0.478 microns
#   but there seems to be issues where the laser goes over etc. and is pretty
#   wide?
#
# Parameters:
#   'inputPoint' (Float) ([length]) A tuple of floats that has pint compatable units of length
#
# Returns:
#   The function returns a tuple with wasatch units
#
def WConvert_PointToCenteredInput(inputPoint):
    val = ((((inputPoint[0].to(unitRegistry.millimeter) + (MM_X / 2.0)) * ((MAX_X - MIN_X) / MM_X)) + MIN_X), ((inputPoint[1].to(unitRegistry.millimeters) + (MM_Y / 2.0)).to(unitRegistry.millimeters) * ((MAX_Y - MIN_Y) / MM_Y)) + MIN_Y)
    return val

#
# Description:
#   Returns the number of scans from the required duration
#
# Parameters:
#   'duration'       (float) How long the scan should last in pint compatable units of time.
#   'pulsePeriod'    (int)   Period of a single pulse in pint compatable units of time.
#   'pulsesPerSweep' (int)   Number of pulses in a primary scan.
#
# Returns:
#   Integer number of scans required.
#
def WConvert_NumScansFromSecs(duration, pulsePeriod = PULSEPERIOD, pulseCount = PULSESPERSWEEP):
    return int(math.ceil((duration) / (PULSEPERIOD * PULSESPERSWEEP)))

#
# Determines the number of complete scans required to achieve
# the desired exposure percentage with the given duty cycle,
# and period of the pulse.
#
# TODO Conversions: Exposure overhaul (may be bugged)
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

#
# Description:
#   Returns the number of seconds required to bleach a line of the given
#   length.
#
# TODO: Conversions: Exposure overhaul
#
def WConvert_BleachExposureTimeSecs(distance):
    return USFORMM * distance.to(unitRegistry.millimeter)
