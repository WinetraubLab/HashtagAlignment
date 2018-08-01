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

import math
import numpy as np

from Wasatch_Main_Commands import *
from Wasatch_Serial_Interface_DirectSerial import Wasatch_Serial_Interface_DirectSerial
from Wasatch_Units import *
from multiples_lines import mult_lines

#--------------------------- The Script ----------------------------------------
#This script draws alignment markers. All units are in mm, sec


#--> Step #1 Connect to Laser
microscopeCommand = Wasatch_Serial_Interface_DirectSerial()
print("Starting")

#--> Step #2 draw Fiducial marker lines
#GCommand_BleachFiducial(microscopeCommand, centerX, centerY, lineLength, markGapBaseWidth, columnRatios, rowRatios, duration):
GCommand_BleachFiducial(microscopeCommand, 0, 0, 5, 0.05, [-1, 0, 2], [-3, 0], 1)

#--> Step #3 draw tick marks
# Inputs
#x = 0.5 -2*(np.cos(45*(180/math.pi))**2)*5*0.001  #[mm] x point of intersection of tick line with x axis
#y = 0.5 -2*(np.cos(45*(180/math.pi))**2)*5*0.001 #[mm] y point of intersection of tick line with x axis
x = 0.25   #[mm] x point of intersection of tick line with x axis
y = 0.55  #[mm] y point of intersection of tick line with x axis
d = 0.25 #[mm] line clearence from the axes
l = 1   #[mm] marker size

#Compute
xysqrt = np.sqrt(x*x+y*y)
Ax = x*(1+d/y)
Ay = -d
Bx = x*(1+d/y+l/xysqrt)
By = -d -l*y/xysqrt
Cx = -d -l*x/xysqrt
Cy = y*(1+d/x+l/xysqrt)
Dx = -d
Dy = y*(1+d/x)
exposure = l/5.0*1.0 #1 sec for 5 mm

AD = xysqrt*(1+d*(1/x+1/y))
text = "AD Length [mm] %f Recomended to be <1.2[mm]" % (AD)
print(text)

#Draw
#print(WCommand_ScanXYRamp(Ax, Ay, Dx, Dy, 1))
mult_lines(Ax, Ay, Dx, Dy, [-15,15])
#print(WCommand_ScanXYRamp(Cx, Cy, Bx, By, 1))
GCommand_BleachLine(microscopeCommand,Ax,Ay,Bx,By, exposure)
GCommand_BleachLine(microscopeCommand,Cx,Cy,Dx,Dy, exposure)

#--> Step # 4 Close
microscopeCommand.close()
print("Done!")

#--> Setp #5 Scan Volume parameters
print("Scan Volume Parameters")
print("When opening wasatch write command 'stop' to stop the laser")
GCommand_TutorialVolumetricScan(-1, -1, 1, 1, 10) #Statx,y Endx,y [mm], # of B Scans

