#
# File: WasatchInterface_Controller_Script
# ------------------------------
# Author: Erick Blankenberg
# Date: 5/29/2018
#
# Description:
#   Executable script. Feel free to fill in whatever
#   commands you want. Mainly used as a demo.
#

#----------------------- Imported Libraries ------------------------------------

import math
import numpy as np

from Wasatch_Main_Commands import *
from Wasatch_Serial_Interface_DirectSerial import Wasatch_Serial_Interface_DirectSerial
from Wasatch_Units import *

#--------------------------- The Script ----------------------------------------

#--> Setup:
microscopeCommand = Wasatch_Serial_Interface_DirectSerial()
print("Starting")
#--> Put your commands here:

# Note:
#
#   You cannot run the Wasatch OCT program and this script at the same time,
#   it seems that port access is exclusive.
#
#   Coordinate system is centered in the middle of the Wasatch OCT
#   field of view as (0, 0). Positive x coordinates are right, and
#   positive y coordinates are up.
#
#   To specify units, multiply your vale by unitRegistry.[unitName] ex,
#   2.5 meters would be written as 'value = 2.5 * unitRegistry.meters'
#   If unitRegistry is not used, commands will default to millimeters
#   and seconds. If the flag 'wasatchUnits' is used, commands will be
#   interpreted directly as wasatch units.
#
# Available Commands:
#   GCommand_BleachLine(microscopeCommand, startX, startY, stopX, stopY, duration, *flags)
#   GCommand_BleachFiducial(microscopeCommand, centerX, centerY, markWidth, markGapWidth, duration, *flags):
#

# Your script here:

# Examples:

# Draws a grid using Wasatch units directly:
"""
rowNumber = 20
rowSpacing = 1000
columnNumber = 20
columnSpacing = 1000
duration = 1 # defaults to seconds

for yIndex in range(-math.ceil(rowNumber / 2), math.ceil(rowNumber / 2)):
    GCommand_BleachLine(microscopeCommand, -columnNumber / 2 * columnSpacing, yIndex * rowSpacing, columnNumber / 2 * columnSpacing, yIndex * rowSpacing, duration, "wasatchUnits")
for xIndex in range(-math.ceil(columnNumber / 2), math.ceil(columnNumber / 2)):
    GCommand_BleachLine(microscopeCommand, xIndex * columnSpacing, -rowNumber / 2 * rowSpacing, xIndex * columnSpacing, rowNumber / 2 * rowSpacing, duration, "wasatchUnits")
"""

# Draws a grid with assumed and real mm

"""
rowNumber = 2
rowSpacing = 0.5 # defaults to mm
columnNumber = 10
columnSpacing = 0.1 * unitRegistry.mm
duration = 1 # defaults to seconds

for yIndex in range(-math.ceil(rowNumber / 2), math.ceil(rowNumber / 2)):
    GCommand_BleachLine(microscopeCommand, -columnNumber / 2 * columnSpacing, yIndex * rowSpacing, columnNumber / 2 * columnSpacing, yIndex * rowSpacing, duration, "showSerial")
for xIndex in range(-math.ceil(columnNumber / 2), math.ceil(columnNumber / 2)):
    GCommand_BleachLine(microscopeCommand, xIndex * columnSpacing, -rowNumber / 2 * rowSpacing, xIndex * columnSpacing, rowNumber / 2 * rowSpacing, duration, "showSerial")
"""

# Instructs the user on how to take a volumetric scan with the desired values:
# Note: Can run just this line alone w/o initiating serial
startX = -2 # Defaults to millimeters
startY = -2
stopX = 2
stopY = 2
bScanAvg = 1
GCommand_TutorialVolumetricScan(startX, startY, stopX, stopY, bScanAvg)


GCommand_TutorialVolumetricScan(-1, -1, 1, 1, 10)

#
#
# Draws a fiducial mark:
#
# centerX = -0.1 # defaults to millimeters
# centerY = 0.1 # defaults to millimeters
# markWidth = 0.5 * unitRegistry.millimeter
# markGapWidth = 100 * unitRegistry.micrometer
# duration = 1 * unitRegistry.seconds
#GCommand_BleachFiducial(microscopeCommand, centerX, centerY, lineLength, markGapBaseWidth, columnRatios, rowRatios, duration):
#

GCommand_BleachFiducial(microscopeCommand, 0, 0, 5, 0.05, [-1, 0, 2], [-1, 1], 1)

#--> Closes connection:
microscopeCommand.close()
print("Done!")
