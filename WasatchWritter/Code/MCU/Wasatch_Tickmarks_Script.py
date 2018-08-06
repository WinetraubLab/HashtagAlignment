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

def main():
    #--------------------------- The Script ----------------------------------------
    #This script draws alignment markers. All units are in mm, sec
    
    #INPUTS:
    #Tick mark position
    x = 0.4   #[mm] x point of intersection of tick line with x axis
    y = 0.3  #[mm] y point of intersection of tick line with x axis
    
    #Other tick mark configuration (not to be edited)
    d = 0.25 #[mm] line clearence from the axes
    l = 1   #[mm] marker size
    laserOvershoot = 0.15 #[mm] Galvo's cannot stop imidatily at the end of the line, there is some overshoot
    
    #Fiducial Marker Inputs
    fiducialVRatios = [-1, 0, 2] # Along Y lines
    fiducialHRatios = [-1, 1] #Along X lines
    fiducialScale = 50e-3 #[mm], minimal line seperation
    
    #Compute Tickmar parameters
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
    
    #Intersection Checks
    AD = xysqrt*(1+d*(1/x+1/y)) - laserOvershoot*2
    text = "AD Length [mm] %f Recomended to be <1.2[mm]" % (AD)
    if AD > 1.2:
        print(text)
        return
    #if (d<abs(min(fiducalVRatios)) or d<abs(max(fiducalHRatios))):
    if (y-y/x*(max(fiducialVRatios)*fiducialScale) < max(fiducialHRatios)*fiducialScale) :
        print("x,y intercepts are too close to the origin, might interfere with fiducial marker")
        return
        
    #--> Step #1 Connect to Laser
    microscopeCommand = Wasatch_Serial_Interface_DirectSerial()
    print("Starting")
    
    #--> Step #2 draw Fiducial marker lines
    #GCommand_BleachFiducial(microscopeCommand, centerX, centerY, lineLength, fiducialVRatios, fiducialHRatios, duration):
    GCommand_BleachFiducial(microscopeCommand, 0, 0, 5, fiducialScale, fiducialVRatios, fiducialHRatios, 1)
    
    #--> Step #3 draw tick marks
    
    #Draw
    GCommand_BleachLine(microscopeCommand,Ax,Ay,Bx,By, exposure)
    GCommand_BleachLine(microscopeCommand,Cx,Cy,Dx,Dy, exposure)
    
    #--> Step # 4 Close
    microscopeCommand.close()
    print("Done!")
    
    #--> Setp #5 Print Scan Volume parameters
    print("Scan Volume Parameters")
    print("When opening wasatch write command 'stop' to stop the laser")
    GCommand_PrintCMD_VolumetricScan(-1, -1, 1, 1, 10) #Statx,y Endx,y [mm], # of B Scans
    
    print("Parameters for scanning parallel to ticmarks")
    GCommand_PrintCMD_MultiParallel(Ax, Ay, Dx, Dy, [-15,15])

if __name__ == '__main__':
    main()
