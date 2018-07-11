#
# File: WasatchInterface_Main_Commands
# ------------------------------
# Author: Erick Blankenberg
# Date: 5/29/2018
#
# Description:
#   These are the top level abstraction commands for
#   bleaching marks with the Wasatch microscope.
#

#------------------------ Imported Libraries -----------------------------------

from Wasatch_Serial_Commands import *
from Wasatch_Serial_Interface_Abstract import Wasatch_Serial_Interface_Abstract
from Wasatch_Units import *

#------------------------ Function Definitions ---------------------------------

#
# Decription:
#   Draws a line. Basic drawing primitive for other functions.
#
# Parameters:
#   'microscopeCommand' Serial interface module
#
#   'startX'        (float) (If unitRegistry units specified [Length],
#                   unspecified assumes mm, if flag 'wasatchUnits' used uses
#                   wasatch units) X coordinate of starting point.
#
#   'startY'        (float) (If unitRegistry units specified [Length],
#                   unspecified assumes mm, if flag 'wasatchUsed' used uses
#                   wasatch units) Y coordinate of starting point.
#
#   'stopX'         (float) (If unitRegistry units specified [Length],
#                   unspecified assumes mm, if flag 'wasatchUnits' used uses
#                   wasatch units) X coordinate of starting point.
#
#   'stopY'         (float) (If unitRegistry units specified [Length],
#                   unspecified assumes mm, if flag 'wasatchUnits' used uses
#                   wasatch units) Y coordinate of starting point.
#
#   'duration'      (float) (If unitRegistry units specified [Time], otherwise assumes seconds)
#                   Duration of the scan line.
#
#   'flags'         (string) (variable number of args) (optional) Flags for the line.
#                       -> 'wasatchUnits' Arguments are interpreted directly as wasatch units
#
def GCommand_BleachLine(microscopeCommand, startX, startY, stopX, stopY, duration, *flags):
    # Sets duty cycle and pulses per sweep
    microscopeCommand.sendCommand(WCommand_ScanPulseDuration(WConvert_PulseDuration()))
    microscopeCommand.sendCommand(WCommand_ScanPulseDelay(WConvert_PulseDelay()))
    microscopeCommand.sendCommand(WCommand_ScanAScans(WConvert_PulsesPerSweep()))
    microscopeCommand.sendCommand(WCommand_ScanBScans(0))
    # Configures paths
    microscopeCommand.sendCommand(WCommand_ScanXYRamp(startX, startY, stopX, stopY, flags))
    # Draws the line, number of scans dependent on previous factors
    microscopeCommand.sendCommand(WCommand_ScanNTimes(WConvert_NumScansFromSecs(duration)), duration)

#
# Description:
#   Draws a pound-sign shaped fiducial mark with an orientation
#   line running through the center vertically.
#
# Parameters:
#   'microscopeCommand' Serial interface module (Subclass of Wasatch_Serial_Interface_Abstract)
#
#   'centerX'           (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Center x coordinate of the mark.
#
#   'centerY'           (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Center y coordinate of the mark.
#
#   'markWidth'         (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) Width of the entire mark.
#
#   'markGapWidth'      (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) Width between outer parralel
#                       members of the fiducial
#
#   'duration'          (float) (If specified unitRegistry units [Time],
#                       otherwise assumed to be in seconds) Duration of draw
#                       time for each line.
#
#   'flags'             (string) (variable number of args) (optional) Flags for the line.
#                       -> 'wasatchUnits' Arguments are interpreted directly as wasatch units
#
def GCommand_BleachFiducial(microscopeCommand, centerX, centerY, markWidth, markGapWidth, duration, *flags):
    # Prints out a hash mark with a line in the middle, consists of 5 lines
    boundXStart = centerPointX - (markWidth / 2)
    boundXStop = centerPointX + (markWidth / 2)
    boundYStart = centerPointY - (markWidth / 2)
    boundYStop = centerPointY + (markWidth / 2)
    # Draws horizontal
    hLowY = centerPointY - (markGapWidth / 2)
    hHighY = centerPointY + (markGapWidth / 2)
    GCommand_BleachLine(microscopeCommand, boundXStart, hLowY, boundXStop, hLowY, duration, flags)
    GCommand_BleachLine(microscopeCommand, boundXStart, hHighY, boundXStop, hHighY, duration, flags)
    # Draws vertical
    vLeftX = centerPointX - (markGapWidth / 2)
    vRightX = centerPointX + (markGapWidth / 2)
    GCommand_BleachLine(microscopeCommand, vLeftX, boundYStart, vLeftX, boundYStop, duration, flags)
    GCommand_BleachLine(microscopeCommand, vRightX, boundYStart, vRightX, boundYStop, duration, flags)
    # Draws central
    GCommand_BleachLine(microscopeCommand, centerPointX, boundYStart, centerPointX, boundYStop, duration, flags)
