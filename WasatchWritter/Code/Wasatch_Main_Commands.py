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
#                       -> 'showSerial'   Serial commands are displayed when sent
#
def GCommand_BleachLine(microscopeCommand, startX, startY, stopX, stopY, duration, *flags):
    duration = WConvert_ToSeconds(duration);
    # Sets duty cycle and pulses per sweep
    microscopeCommand.sendCommand(WCommand_ScanPulseDuration(WConvert_PulseDuration()), 0, *flags)
    microscopeCommand.sendCommand(WCommand_ScanPulseDelay(WConvert_PulseDelay()), 0, *flags)
    microscopeCommand.sendCommand(WCommand_ScanAScans(WConvert_PulsesPerSweep()), 0, *flags)
    microscopeCommand.sendCommand(WCommand_ScanBScans(0), 0, *flags)
    # Configures paths
    microscopeCommand.sendCommand(WCommand_ScanXYRamp(startX, startY, stopX, stopY, *flags), 0, *flags)
    # Draws the line, number of scans dependent on previous factors
    microscopeCommand.sendCommand(WCommand_ScanNTimes(WConvert_NumScansFromSecs(duration)), duration, *flags)

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
#                       -> 'showSerial'   Serial commands are displayed when sent
#
def GCommand_BleachFiducial(microscopeCommand, centerX, centerY, markWidth, markGapWidth, duration, *flags):
    # Prints out a hash mark with a line in the middle, consists of 5 lines
    boundXStart = centerX - (markWidth / 2)
    boundXStop = centerX + (markWidth / 2)
    boundYStart = centerY - (markWidth / 2)
    boundYStop = centerY + (markWidth / 2)
    # Draws horizontal
    hLowY = centerY - (markGapWidth / 2)
    hHighY = centerY + (markGapWidth / 2)
    GCommand_BleachLine(microscopeCommand, boundXStart, hLowY, boundXStop, hLowY, duration, *flags)
    GCommand_BleachLine(microscopeCommand, boundXStart, hHighY, boundXStop, hHighY, duration, *flags)
    # Draws vertical
    vLeftX = centerX - (markGapWidth / 2)
    vRightX = centerX + (markGapWidth / 2)
    GCommand_BleachLine(microscopeCommand, vLeftX, boundYStart, vLeftX, boundYStop, duration, *flags)
    GCommand_BleachLine(microscopeCommand, vRightX, boundYStart, vRightX, boundYStop, duration, *flags)
    # Draws central
    GCommand_BleachLine(microscopeCommand, centerX, boundYStart, centerX, boundYStop, duration, *flags)

#
# Description:
#   Provides test to the user to type into the terminal to get the desired 3d
#   volumetric scan.
#
# Parameters:
#   'centerX'           (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Center x coordinate of the mark.
#
#   'centerY'           (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Center y coordinate of the mark.
#
#   'width'             (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) Width of the entire mark.
#
#   'height'            (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) Width between outer parralel
#                       members of the fiducial
#
#   'flags'             (string) (variable number of args) (optional) Flags for the line.
#                       -> 'wasatchUnits' Arguments are interpreted directly as wasatch units
#
def GCommand_TutorialVolumetricScan(startX, startY, stopX, stopY, brepeats, *flags):
    print("After setting the desired A and B scan values, type this command into the setup window: ")
    print(WCommand_ScanXYRamp(startX, startY, stopX, stopY, brepeats, *flags))
    print("Then hit \"Save Volume\"")
