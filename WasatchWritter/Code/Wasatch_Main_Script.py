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

# Your script here:

# Examples:
#
# Draws a grid
#
# Row_Number = 200
# Row_Spacing = 100
# Column_Number = 100
# Column_SPacing = 200
# Duration = 1
#
# for xIndex in range
#

#lineHeight = 5.0 unitRegistry.millimeters
#lineXPosition = 0.0 unitRegistry.millimeters from center
#exposure = 1 unitRegistry.second per line
#GCommand_BleachLine(microscopeCommand, (5.0+lineXPosition, 5.0-lineHeight/2), (5.0+lineXPosition, 5.0+lineHeight/2), exposure)

#(x,y) in mm, args are (module, center, length of mark, seperation b/ outermost pairs, exposure per line in (s), "V" is vertical, "H" is horizontal)
#GCommand_BleachFiducial(microscopeCommand, (5.0, 5.0), 5.0, 0.1, 5, "V")


#This part below creates lines in different exposure times
#lineHeight = 5.0 * unitRegistry.millimeters
#exposures = [0.1, 0.2, 0.5, 1, 2, 5] * unitRegistry.second
#for i in range(len(exposures)):
#    lineXPosition = 2.0 + i*0.1 #[mm]
#    exposure = exposures[i] #[sec] per line
#    print('Current exposure :', exposure)
#    GCommand_BleachLine(microscopeCommand, (lineXPosition, 5.0-lineHeight/2), (lineXPosition, 5.0+lineHeight/2), exposure)
print("Drawing grid")
#GCommand_BleachGrid(microscopeCommand, (0 * unitRegistry.millimeters, 0 * unitRegistry.millimeters), 30, 0, 100 * unitRegistry.micrometer, 0 * unitRegistry.millimeter, 5 * unitRegistry.millimeter, 0 * unitRegistry.millimeter, 1 * unitRegistry.second)
GCommand_TestGrid(microscopeCommand, (5000, 5000), 50, 100, 400, 200, 2 * unitRegistry.seconds)
#GCommand_TestBars(microscopeCommand, (5000, 5000), 50, 200, 10000, 1 * unitRegistry.second)
print("Done!")
#--> Closes connection:
microscopeCommand.close()
