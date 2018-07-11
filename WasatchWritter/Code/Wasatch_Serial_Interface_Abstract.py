#
# File: Wasatch_Serial_Interface_Abstract
# ------------------------------
# Author: Erick Blankenberg
# Date: 5/12/2018
#
# Description:
#   Derivatives of this abstract class provide access
#   to the serial connection with the Wasatch microscope.
#

#------------------------ Class Definition -------------------------------------

class Wasatch_Serial_Interface_Abstract:

    #-------------------- Public Members ---------------

    # Initializes class and establishes serial with Wasatch
    def __init__(self):
        raise NotImplementedError("Subclass for Wasatch Interface must have its own initialization.")

    # Returns whether the microscope was able to establish a connection
    def connectedToMicroscope(self):
        raise NotImplementedError("Subclass for Wasatch Interface must have its own microscope state.")

    # Attempts to reestablish connection with the microscope
    def reconnectToMicroscope(self):
        raise NotImplementedError("Subclass for Wasatch Interface must have its own reconnection.")

    # Sends a serial command to the Wastach and then delays for 'time' seconds
    def sendCommand(self, command, time):
        raise NotImplementedError("Subclass for Wasatch Interface must have its own command method.")

    # Safely disconnects the microscope from the program
    def close(self):
        raise NotImplementedError("Subclass for Wasatch Interface must have its own closing method.")
