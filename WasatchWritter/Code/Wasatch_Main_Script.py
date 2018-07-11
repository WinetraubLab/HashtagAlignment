#
# File: WasatchInterface_Controller_Script
# ------------------------------
# Author: Erick Blankenberg
# Date: 5/29/2018
#
# Description:
#   Executable script. Feel free to fill in whatever
#   commands you want.
#

#----------------------- Imported Libraries ------------------------------------

from Wasatch_Main_Commands import *
from Wasatch_Serial_Interface_AutoGUI import Wasatch_Serial_Interface_AutoGUI
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
#
# Draws a grid using Wasatch units directly:
#
# rowNumber = 200
# rowSpacing = 100
# columnNumber = 100
# columnSpacing = 200
# duration = 1 # defaults to seconds
#
# for xIndex in range(-rowNumber / 2, rowNumber / 2):
#   GCommand_BleachLine(microscopeCommand, -columnNumber / 2 * columnSpacing, rowNumber * rowSpacing, columnNumber / 2 * columnSpacing, rowNumber * rowSpacing, duration, "wasatchUnits")
# for yIndex in range(-columnNumber / 2, columnNumber / 2):
#   GCommand_BleachLine(microscopeCommand, columnNumber * columnSpacing, -rowNumber / 2 * rowSpacing, columnNumber * columnSpacing, rowNumber / 2 * rowSpacing, duration, "wasatchUnits")
#
# Draws a fiducial mark:
#
# centerX = -0.1 # defaults to millimeters
# centerY = 0.1 # defaults to millimeters
# markWidth = 0.5 * unitRegistry.millimeter
# markGapWidth = 100 * unitRegistry.micrometer
# duration = 1 * unitRegistry.seconds
#
# GCommand_BleachFiducial(microscopeCommand, centerX, centerY, markWidth, markGapWidth, duration):
#

#This part below creates lines in different exposure times
#lineHeight = 5.0 * unitRegistry.millimeters
#exposures = [0.1, 0.2, 0.5, 1, 2, 5] * unitRegistry.second
#for i in range(len(exposures)):
#    lineXPosition = 2.0 + i*0.1 #[mm]
#    exposure = exposures[i] #[sec] per line
#    print('Current exposure :', exposure)
#    GCommand_BleachLine(microscopeCommand, (lineXPosition, 5.0-lineHeight/2), (lineXPosition, 5.0+lineHeight/2), exposure)

#--> Closes connection:
microscopeCommand.close()
print("Done!")
