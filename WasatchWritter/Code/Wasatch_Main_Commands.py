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
#   Draws a line.
#
# Parameters:
#   'microscopeCommand' Serial interface module
#   'startPoint'        (Tuple of floats) ([Length]) Point of form (x, y)
#   'endPoint'          (Tuple of floats) ([Length]) Point of form (x, y)
#   'duration'          (float) ([Time, sec])             Duration of scan
#
def GCommand_BleachLine(microscopeCommand, startPoint, stopPoint, duration):
    # Sets duty cycle and pulses per sweep
    microscopeCommand.sendCommand(WCommand_ScanPulseDuration(WConvert_PulseDuration()))
    microscopeCommand.sendCommand(WCommand_ScanPulseDelay(WConvert_PulseDelay()))
    microscopeCommand.sendCommand(WCommand_ScanAScans(WConvert_PulsesPerSweep()))
    microscopeCommand.sendCommand(WCommand_ScanBScans(0))
    # Configures paths
    microscopeCommand.sendCommand(WCommand_ScanXYRamp(startPoint, stopPoint))
    # Draws the line, number of scans dependent on previous factors
    microscopeCommand.sendCommand(WCommand_ScanNTimes(WConvert_NumScansFromSecs(duration)), duration)

#
# Description:
#   Draws a pound-sign shaped fiducial mark with an orientation
#   line running through the center either horizontally or vertically.
#
# Parameters:
#   'microscopeCommand' Serial interface module (Subclass of Wasatch_Serial_Interface_Abstract)
#   'centerPoint'       (Tuple of floats) ([Length, mm])  Point in form of (x, y) for center of the mark
#   'markWidth'         (float) ([Length])            Width of the entire mark.
#   'markGapWidth'      (float) ([Length])            Width between outer parralel members of the fiducial
#   'duration'          (float) ([Time, sec])              Duration of draw time for each line in seconds
#   'orientation'       (string) ("H" or "V")         Whether the orientation line is drawn horizontally or vertically through the centerPoint
#
def GCommand_BleachFiducial(microscopeCommand, centerPoint, markWidth, markGapWidth, duration, orientation):
    # Prints out a hash mark with a line in the middle, consists of 5 lines
    boundXStart = centerPoint[0] - (markWidth / 2)
    boundXStop = centerPoint[0] + (markWidth / 2)
    boundYStart = centerPoint[1] - (markWidth / 2)
    boundYStop = centerPoint[1] + (markWidth / 2)
    # Draws horizontal
    hLowY = centerPoint[1] - (markGapWidth / 2)
    hHighY = centerPoint[1] + (markGapWidth / 2)
    GCommand_BleachLine(microscopeCommand, (boundXStart, hLowY), (boundXStop, hLowY), duration)
    GCommand_BleachLine(microscopeCommand, (boundXStart, hHighY), (boundXStop, hHighY), duration)
    # Draws vertical
    vLowX = centerPoint[0] - (markGapWidth / 2)
    vHighX = centerPoint[0] + (markGapWidth / 2)
    GCommand_BleachLine(microscopeCommand, (vLowX, boundYStart), (vLowX, boundYStop), duration)
    GCommand_BleachLine(microscopeCommand, (vHighX, boundYStart), (vHighX, boundYStop), duration)
    # Draws central
    if(orientation == "V"):
        GCommand_BleachLine(microscopeCommand, (centerPoint[0], boundYStart), (centerPoint[0], boundYStop), duration)
    if(orientation == "H"):
        GCommand_BleachLine(microscopeCommand, (boundXStart, centerPoint[1]), (boundXStop, centerPoint[1]), duration)

#
# Description:
#   Draws a test grid in wasatch units for testing purposes.
#
# Parameters:
#   'microscopeCommand' Serial interface module
#   'startPoint'        (integer) (Wasatch units) The upper left hand corner of the grid
#   'columns'           (integer)                 Number of to draw
#   'rows'              (integer)                 Number of rows to draw
#   'colSpacing'        (integer) (Wasatch units) Distance between columns
#   'rowSpacing'        (integer) (Wasatch units) Distance between rows
#   'duration'          (integer) ([Time])        Dwell time per line
#
def GCommand_TestGrid(microscopeCommand, startPoint, columns, rows, colSpacing, rowSpacing, duration):
    microscopeCommand.sendCommand(WCommand_ScanPulseDuration(WConvert_PulseDuration()))
    microscopeCommand.sendCommand(WCommand_ScanPulseDelay(WConvert_PulseDelay()))
    microscopeCommand.sendCommand(WCommand_ScanAScans(WConvert_PulsesPerSweep()))
    microscopeCommand.sendCommand(WCommand_ScanBScans(0))
    for colIndex in range(0, columns):
        microscopeCommand.sendCommand("xy_ramp %d %d %d %d" % (startPoint[0] + (colSpacing * colIndex), startPoint[0] + (colSpacing * colIndex), startPoint[1], startPoint[1] + (rowSpacing * (rows - 1))))
        microscopeCommand.sendCommand(WCommand_ScanNTimes(WConvert_NumScansFromSecs(duration)), duration)
    for rowIndex in range(0, rows):
        microscopeCommand.sendCommand("xy_ramp %d %d %d %d" % (startPoint[0], startPoint[0] + (colSpacing * (columns - 1)), startPoint[1] + (rowSpacing * rowIndex), startPoint[1] + (rowSpacing * rowIndex)))
        microscopeCommand.sendCommand(WCommand_ScanNTimes(WConvert_NumScansFromSecs(duration)), duration)

#
# Description:
#   Draws a series of parralel lines in wasatch units for testing
#
# Parameters:
#   'microscopeCommand' Serial interface module
#   'startPoint'        (integer) (Wasatch units) The upper left hand corner of the grid
#   'columns'           (integer)                 Number of to draw
#   'colSpacing'        (integer) (Wasatch units) Distance between columns
#   'colLength'         (integer) (Wasatch units) Length of a single column
#   'duration'          (integer) ([Time])        Dwell time per line
#
def GCommand_TestBars(microscopeCommand, startPoint, columns, colSpacing, colLength, duration):
    microscopeCommand.sendCommand(WCommand_ScanPulseDuration(WConvert_PulseDuration()))
    microscopeCommand.sendCommand(WCommand_ScanPulseDelay(WConvert_PulseDelay()))
    microscopeCommand.sendCommand(WCommand_ScanAScans(WConvert_PulsesPerSweep()))
    microscopeCommand.sendCommand(WCommand_ScanBScans(0))
    for colIndex in range(0, columns):
        microscopeCommand.sendCommand("xy_ramp %d %d %d %d" % (startPoint[0] + (colSpacing * colIndex), startPoint[0] + (colSpacing * colIndex), startPoint[1], startPoint[1] + colLength))
        microscopeCommand.sendCommand(WCommand_ScanNTimes(WConvert_NumScansFromSecs(duration)), duration)

#
# Description:
#   Draws a grid.
#
# Parameters:
#   'microscopeCommand' Serial interface module
#   'startPoint'        (integer) (Wasatch units) The upper left hand corner of the grid
#   'columns'           (integer)                 Number of to draw
#   'rows'              (integer)                 Number of rows to draw
#   'colSpacing'        (integer) ([Length])      Distance between columns
#   'rowSpacing'        (integer) ([Length])      Distance between rows
#   ''
#   'duration'          (integer) ([Time])        Dwell time per line
#
def GCommand_BleachGrid(microscopeCommand, centerPoint, columns, rows, colSpacing, rowSpacing, colLength, rowLength, duration):
    microscopeCommand.sendCommand(WCommand_ScanPulseDuration(WConvert_PulseDuration()))
    microscopeCommand.sendCommand(WCommand_ScanPulseDelay(WConvert_PulseDelay()))
    microscopeCommand.sendCommand(WCommand_ScanAScans(WConvert_PulsesPerSweep()))
    microscopeCommand.sendCommand(WCommand_ScanBScans(0))
    for colIndex in range(0, columns):
        GCommand_BleachLine(microscopeCommand, (centerPoint[0] + (colIndex - columns / 2) * colSpacing, centerPoint[1] + colLength / 2), (centerPoint[0] + (colIndex - columns / 2) * colSpacing, centerPoint[1] - colLength / 2), duration)
    for rowIndex in range(0, rows):
        GCommand_BleachLine(microscopeCommand, (centerPoint[0] - rowLength / 2, centerPoint[1] + (rowIndex - rows / 2)), (centerPoint[0] + rowLength / 2, centerPoint[1] + (rowIndex - rows / 2)), duration)

#
# Description:
#  Sets the scanner to continuously draw a 3d volumetric scan.
#  Note: Assumes that you have set the aScans and bScans in the software
#
# Parameters:
#   'microscopeCommand' Serial interface module
#   'centerPoint'       (Tuple of floats) ([Length]) Point in form of (x, y) for center of the mark
#   'scanWidth'         (float) ([Length])           Width of volumetric scan
#   'scanHeight'        (float) ([Length])           Height of volumetric scan
#
def GCommand_3DVolumetric(microscopeCommand, centerPoint, scanWidth, scanHeight, aScans = 1024, bScans = 1024):
    boundXStart = centerPoint[0] - (markWidth / 2)
    boundXStop = centerPoint[0] + (markWidth / 2)
    boundYStart = centerPoint[1] - (markWidth / 2)
    boundYStop = centerPoint[1] + (markWidth / 2)
    upperLeftCorner = (boundXStart, boundYStart)
    lowerRightCorner = (boundXStop, boundYStop)

    microscopeCommand.sendCommand(WCommand_ScanAScans(aScans))
    microscopeCommand.sendCommand(WCommand_ScanBScans(bScans + 4)) # Wasatch adds four
    microscopeCommand.sendCommand(WCommand_ScanXYRamp(upperLeftCorner, lowerRightCorner))
    microscopeCommand.sendCommand(WCommand_ScanNTimes(0))

#
# Description:
#   Continuously draws a 3d volumetric scan but with finer control over
#   the dimensions of the scans.
#
#  Parameters:
#   'microscopeCommand' Serial interface module
#   'centerPoint'       (Tuple of floats) ([Length]) Point in form of (x, y) for center of the mark
#   'pixelWidth'        (float) ([Length])           The width of a single pixel
#   'pixelHeight'       (float) ([Length])           The height of a single pixel
#   'pixelsWide'        (integer)                    Number of pixels per scan line
#   'pixelsTall'        (integer)                    Number of scan lines
#   'verbose'           (bool)                       If true, prints out the desired aScans and bScans that the user must
#                                                    enter into the wasatch program manually
#
def GCommand_3DVolumetric_Precise(microscopeCommand, centerPoint, pixelWidth, pixelHeight, pixelsWide, pixelsTall, verbose = 'false'):
    boundXStart = centerPoint[0] - pixelWidth * pixelsWide / 2
    boundXStop = centerPoint[0] + pixelWidth * pixelsWide / 2
    boundYStart = centerPoint[1] - pixelHeight * pixelsHigh / 2
    boundYStop = centerPoint[1] + pixelHeight * pixelsHigh / 2
    upperLeftCorner = (boundXStart, boundYStart)
    lowerRightCorner = (boundXStop, boundYStop)

    if verbose:
        print('GCommand 3DVolumetric Precise, User action required.')
        print('In the OCT Volume tab:')
        print('1). Set A-scans to %d' % (pixelsWide))
        print('2). Set B-scans to %d' % (pixelsTall))

    microscopeCommand.sendcommand(WCommand_ScanAScans(pixelsWide))
    microscopeCommand.sendCommand(WCommand_ScanBScans(pixelsTall + 4)) # Wasatch adds 4
    microscopeCommand.sendCommand(WCommand_ScanXYRamp(upperLeftCorner, lowerRightCorner))
    microscopeCommand.sendCommand(WCommand_ScanNTimes(0))
