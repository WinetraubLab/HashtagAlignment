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
#                       -> 'disableOutput' Serial commands are not sent to the microcontroller
#
def GCommand_BleachLine(microscopeCommand, startX, startY, stopX, stopY, duration, *flags):
    duration = WConvert_ToSeconds(duration);
    # Sets duty cycle and pulses per sweep
    microscopeCommand.sendCommand(WCommand_ScanPulseDuration(WConvert_PulseDuration()), 0, *flags)
    microscopeCommand.sendCommand(WCommand_ScanPulseDelay(WConvert_PulseDelay()), 0, *flags)
    microscopeCommand.sendCommand(WCommand_ScanAScans(WConvert_PulsesPerSweep()), 0, *flags)
    microscopeCommand.sendCommand(WCommand_ScanBScans(0), 0, *flags)
    # Configures paths
    microscopeCommand.sendCommand(WCommand_ScanXYRamp(startX, startY, stopX, stopY, 1, *flags), 0, *flags)
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
#                       used uses Wasatch units) How far lines extend past the mark.
#
#   'markBaseGapWidth'  (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units) Base gap between lines in the
#                       mark. Set the actual values with the 'ratios' parameter.
#
#   'xRatios'           (tuple of float) Locations of lines perpendicular to x
#                       axis along x axis at multiples of 'markBaseGapWidth' away
#                       from the origin. Negative ratios draw at negative values
#                       relative to the center. Zero would draw along the origin
#                       axis. Positive values draw beyond the origin.
#
#   'yRatios'           (tuple of float) Locations of lines perpendicular to y
#                       axis along y axis at multiples of 'markBaseGapWidth' away
#                       from the origin. Negative ratios draw at negative values
#                       relative to the center. Zero would draw along the origin
#                       axis. Positive values draw beyond the origin.
#
#   'duration'          (float) (If specified unitRegistry units [Time],
#                       otherwise assumed to be in seconds) Duration of draw
#                       time for each line.
#
#   'flags'             (string) (variable number of args) (optional) Flags for the line.
#                       -> 'wasatchUnits' Arguments are interpreted directly as wasatch units
#                       -> 'showSerial'   Serial commands are displayed when sent
#                       -> 'disableOutput' Serial commands are not sent to the microcontroller
#
def GCommand_BleachFiducial(microscopeCommand, centerX, centerY, markWidth, markBaseGapWidth, xRatios, yRatios, duration, *flags):
    # Draws horizontal
    for currentY in yRatios:
        boundXStart = centerX - (markWidth / 2)
        boundXStop = centerX + (markWidth / 2)
        yPosition = centerY + (currentY * markBaseGapWidth)
        GCommand_BleachLine(microscopeCommand, boundXStart, yPosition, boundXStop, yPosition, duration, *flags)
    # Draws vertical
    for currentX in xRatios:
        boundYStart = centerY - (markWidth / 2)
        boundYStop = centerY + (markWidth / 2)
        xPosition = centerX + (currentX * markBaseGapWidth)
        GCommand_BleachLine(microscopeCommand, xPosition, boundYStart, xPosition, boundYStop, duration, *flags)

#
# Description:
#   Provides test to the user to type into the terminal to get the desired 3d
#   volumetric scan. The start and stop points define the bounding opposite corners
#   of the rectangular region of the volume to be scanned. The scan proceeds
#   horizontally along the X axis in the direction away from the x coordinate
#   of the stop point towards the x coordinate of the stop point. Similarily, the
#   scan starts at the height of the start point and proceeds to the height of the
#   end point. Choose your start and end points accordingly.
#
# Parameters:
#   'startX'           (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Start X coordinate of the scan.
#
#   'startY'           (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Start Y coordinate of the scan.
#
#   'stopX'            (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Stop X coordinate of the scan.
#
#   'stopY'            (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Stop Y coordinate of the scan.
#
#   'flags'             (string) (variable number of args) (optional) Flags for the line.
#                       -> 'wasatchUnits'  Arguments are interpreted directly as wasatch units
#                       -> 'showSerial'    Serial commands are displayed when sent
#                       -> 'disableOutput' Serial commands are not sent to the microcontroller
#
def GCommand_TutorialVolumetricScan(startX, startY, stopX, stopY, brepeats, *flags):
    print("After setting the desired A and B scan values, type this command into the setup window: ")
    print(WCommand_ScanXYRamp(startX, startY, stopX, stopY, brepeats, *flags))
    print("Then hit \"update\" and then \"Save Volume\" when you are ready to collect data.")
