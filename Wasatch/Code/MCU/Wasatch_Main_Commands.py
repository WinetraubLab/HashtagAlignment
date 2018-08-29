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
import numpy as np
import cv2
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
# Decription:
#   Draws a line. Instead of drawing with a constant velocity, draws
#   the given line a defined number of times for the given duration.
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
#   'numScans'      (integer) Number of times to scan the line during the
#                   bleaching process. This is the number of forward scans.
#
#   'flags'         (string) (variable number of args) (optional) Flags for the line.
#                       -> 'wasatchUnits' Arguments are interpreted directly as wasatch units
#                       -> 'showSerial'   Serial commands are displayed when sent
#                       -> 'disableOutput' Serial commands are not sent to the microcontroller
#
def GCommand_BleachLineNTimes(microscopeCommand, startX, startY, stopX, stopY, duration, numScans, *flags):
        duration = WConvert_ToSeconds(duration);
        durationPerOneWay = duration / (numScans * 2.0); # Return path is same as forward path
        # Sets duty cycle and pulses per sweep
        microscopeCommand.sendCommand(WCommand_ScanPulseDuration(WConvert_PulseDuration()), 0, *flags)
        microscopeCommand.sendCommand(WCommand_ScanPulseDelay(WConvert_PulseDelay()), 0, *flags)
        microscopeCommand.sendCommand(WCommand_ScanAScans(durationPerOneWay / (WConvert_PulseDuration() + WConvert_PulseDelay())), 0, *flags)
        microscopeCommand.sendCommand(WCommand_ScanBScans(0), 0, *flags)
        microscopeCommand.sendCommand(WCommand_ScanReturnClockDivider(1), 0, *flags)
        microscopeCommand.sendCommand(WCommand_ScanReturnSetDuration(WConvert_PulseDuration() + WConvert_PulseDelay()), 0, *flags)
        # Configures paths
        microscopeCommand.sendCommand(WCommand_ScanXYRamp(startX, startY, stopX, stopY, 1, *flags), 0, *flags)
        # Draws the line, number of scans dependent on previous factors
        microscopeCommand.sendCommand(WCommand_ScanNTimes(numScans), duration, *flags)

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
#   'verticalRatios'    (tuple of float) Locations of lines perpendicular to x
#                       axis along x axis at multiples of 'markBaseGapWidth' away
#                       from the origin. Negative ratios draw at negative values
#                       relative to the center. Zero would draw along the origin
#                       axis. Positive values draw beyond the origin.
#
#   'horizontalRatios'  (tuple of float) Locations of lines perpendicular to y
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
def GCommand_BleachFiducial(microscopeCommand, centerX, centerY, lineLength, markBaseGapWidth, verticalRatios, horizontalRatios, duration, *flags):
    # Draws horizontal
    for currentY in horizontalRatios:
        boundXStart = centerX - (lineLength / 2)
        boundXStop = centerX + (lineLength / 2)
        yPosition = centerY + (currentY * markBaseGapWidth)
        GCommand_BleachLineNTimes(microscopeCommand, boundXStart, yPosition, boundXStop, yPosition, duration, 1, *flags)
    # Draws vertical
    for currentX in verticalRatios:
        boundYStart = centerY - (lineLength / 2)
        boundYStop = centerY + (lineLength / 2)
        xPosition = centerX + (currentX * markBaseGapWidth)
        GCommand_BleachLineNTimes(microscopeCommand, xPosition, boundYStart, xPosition, boundYStop, duration, 1, *flags)

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
def GCommand_PrintCMD_VolumetricScan(startX, startY, stopX, stopY, brepeats, *flags):
    print("After setting the desired A and B scan values, type this command into the setup window: ")
    print(WCommand_ScanXYRamp(startX, startY, stopX, stopY, brepeats, *flags))
    print("Then hit \"update\" and then \"Save Volume\" when you are ready to collect data.")

#
# Description:
#   Provides test to the user to type into the terminal to get the desired 3d
#   volumetric scan. This version assumes that you have a trdelay of 40 and compensates
#   for shifting and scaling distortion.
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
def GCommand_PrintCMD_VolumetricScanAdjusted(startX, startY, stopX, stopY, brepeats, *flags):
    startX = 1.026409 * WConvert_ToMillimeters(startX) + 5.493 * unitRegistry.microns()
    stopX = 1.026409 * WConvert_ToMillimeters(stopX) + 5.493 * unitRegistry.microns()
    startY = 1.0269 * WConvert_ToMillimeters(startY)tY + 4.939 * unitRegistry.microns()
    stopY = 1.02269 * WConvert_ToMillimeters(stopY) + 4.939 * unitRegistry.microns()
    GCommand_PrintCMD_VolumetricScan(startX, startY, stopX, stopY, brepeats, *flags)

#
# Description"
#    Prints out the required commands to bleach multiple parralel lines
#
#
# Parameters:
#   'Ax'                (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Start X value of reference line.
#
#   'Ay'                (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Start Y value of reference line.
#
#   'Dx'                (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). End X value of reference line.
#
#   'Dy'                (float) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). End Y value of reference line.
#
#   'change'            (Array) (If specified unitRegistry units [Length], if
#                       no units assumes millimeters, if flag 'wasatchUnits' is
#                       used uses Wasatch units). Sequence of parralel distances
#                       for more lines.
#
#
def GCommand_PrintCMD_MultiParallel(Ax, Ay, Dx, Dy, change):
    #x = 0.5 -2*(np.cos(45*(180/math.pi))**2)*5*0.001  #[mm] x point of intersection of tick line with x axis
    #y = 0.5 -2*(np.cos(45*(180/math.pi))**2)*5*0.001 #[mm] y point of intersection of tick line with x axis

    change = np.array(change)

    ratio = abs((Dy-Dx)/(Ay-Ax))
    theta =  -np.arctan(ratio)*180/math.pi

    coord =np.array([[Ax,Ay],[Dx,Dy]])
    numpts = coord.shape[1]  # shoudl always be 2, as 2 pts define a line



    rot = cv2.getRotationMatrix2D((0,0), theta,1)
    rot_ = rot[:2,:2]
    coord_rot =np.dot(rot_,coord)

    newcord = np.zeros((2,numpts,len(change)))

    for ind,c in enumerate(change):
        for pt in range(numpts):
            newcord[0,pt,ind] = coord_rot[0,pt]
            newcord[1,pt,ind] = coord_rot[1,pt] + c


    newcord_reshape = np.reshape(newcord,[2,-1])

    invrot = cv2.getRotationMatrix2D((0,0), -theta,1)
    invrot_ = invrot[:2,:2]
    coord_final_reshape = np.dot(invrot_,newcord_reshape)
    coord_final = np.reshape(coord_final_reshape,[2,2,-1])

    for ind,c in enumerate(change):
        Ax_ = coord_final[0,0,ind]
        Ay_ = coord_final[1,0,ind]
        Dx_ = coord_final[0,1,ind]
        Dy_ = coord_final[1,1,ind]

        print(WCommand_ScanXYRamp(Ax_, Ay_, Dx_, Dy_, 1))
