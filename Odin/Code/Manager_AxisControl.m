%
% File: Manager_AxisControl.m
% -------------------
% Author: Erick Blankenberg
% Date 8/1/2018
% 
% Description:
%   This class acts as hardware interface for the axis control system.
%   There is a c++ sdk for this device provided by Thorlabs, but it seems 
%   to only be compatable with windows 7 and has some other strange
%   restrictions. The documentation comes with a serial reference. The
%   header file for the documentation seems to imply that there is a lot of
%   complexity to the device, there may be missing commands.
%

%
% Relevant Documentation:
%
% Serial settings:
%   BaudRate = 9600
%   Address = 1
%   
% Conversion factors (units in nm)
%   LNR: 39.0625        - Refers to LNR50S(/M), not in use
%   PLS: 211.6667       - Refers to PLS-X or PLS-XY, which we do use
%   AScope Z: 1.0       - ?
%   BScope: 500.0       - ?
%   BScope Z: 100.0     - ?
%   Objective Mover 1.0 - ?
%
% Serial commands:
%   Set Encoder         - Used to set encoder count (resets reference?)
%   Stop                - Stops motion of the given channel, (immediate or profiled?)
%   Query               - Retrieves motor position.
%   GoTo                - Sends the motor to the given position (relative?)
%   QueryMotorStatus    - Returns whether the motor is still working.
%   

%
% In our case, channel A is a ZFM2020, channel B and C are PLS-XY stages (X
% then Y)
%

classdef Manager_AxisControl < handle
    properties(Access = 'public')
        serialConnection;
        ZPORT = 0;
        YPORT = 1;
        XPORT = 2;
        UMPERPLSUNIT = (211.6667*10^-3);
        SERIAL_BAUD = 9600;      % Baud rate used
        SERIAL_BITS = 8;          % Number of bits per message
        SERIAL_PARITY = 'none';   % Do not use parity
        SERIAL_TERMINATOR = '\n'; % Uses /n or CRLF
        SERIAL_STOPBIT = 1;       % From sheet
        DELAYTIME = 5;            % Wait for motor in seconds
    end
    
    methods(Access = 'public') 
        function obj = Manager_AxisControl
        % Tries to find a valid serial port
            serialOptions = instrfind('Status', 'open');
            obj.serialConnection = 0;
            for index = 1:length(serialOptions)
                serial(serialOptions(index))
                obj.serialConnection = serial(serialOptions(index));
                obj.serialConnection.BaudRate = obj.SERIAL_BAUD;
                obj.serialConnection.DataBits = obj.SERIAL_BITS;
                obj.serialConnection.Parity = obj.SERIAL_PARITY;
                
                % Tests to see if this is a platform
                fclose(obj.serialConnection);
                fopen(obj.serialConnection);
                obj.queryPosition(1)
                if(obj.queryPosition(1) >= 0)
                    break
                end
                fclose(obj.serialConnection);
                delete(obj.serialConnection);
                obj.serialConnection = 0;
            end
        end
        
        %
        % Description:
        %   These function set the position of each axis in
        %   um relative to the start position.
        %
        function setX(obj, x)
            obj.goToPosition(obj.XPORT, x / obj.UMPERPLSUNIT);
        end
        
        function setY(obj, y)
            obj.goToPosition(obj.YPORT, y / obj.UMPERPLSUNIT);
        end
        
        function setZ(obj, z)
            obj.goToPosition(obj.ZPORT, z / obj.UMPERPLSUNIT);
        end
        
        %
        % Description:
        %   These functions return the current position of the
        %   platform in um.
        %
        % Returns:
        %   Value in um if succesful, -1 if there was a communication
        %   failure.
        %
        function value = getX(obj)
            value = obj.queryPosition(obj.XPORT) * obj.UMPERPLSUNIT;
        end
        
        function value = getY(obj)
            value = obj.queryPosition(obj.YPORT) * obj.UMPERPLSUNIT;
        end
        
        function value = getZ(obj)
            value = obj.queryPosition(obj.ZPORT); % * obj.UMPERPLSUNIT;
        end
        
        %
        % Description:
        %   Sets each axis to its home position.
        %
        function homeAll(obj) 
            obj.homeX();
            obj.homeY();
            obj.homeZ();
        end
        
        function homeX(obj)
            obj.goToPosition(obj.XPORT, 0);
            obj.setEncoderCounter(obj.XPORT, 0);
        end

        function homeY(obj)
            obj.goToPosition(obj.YPORT, 0);
            obj.setEncoderCounter(obj.YPORT, 0);
        end
        
        function homeZ(obj)
            obj.goToPosition(obj.ZPORT, 0);
            obj.setEncoderCounter(obj.ZPORT, 0);
        end
    end
    
    methods(Access = 'private')
        %
        % Description:
        %   Sets the encoder counter in the microcontroller for the
        %   given channel.
        %
        function setEncoderCounter(obj, channelIdentity, encoderCount)
            % Format is ([09-04-06-00-00-00][uint16 channel][int32 data])
            commandStructure = uint8([9, 4, 6, 0, 0, 0, channelIdentity, 0, typecast(int32(encoderCount), 'uint8')]);
            % Sends
            fwrite(obj.serialConnection, commandStructure, 'uint8');
        end
        
        %
        % Description:
        %   Stops the motor associated with the given channel.
        %
        % Parameters:
        %   'channelIdentity' (scalar) The target motor. Either 0, 1, or 2.
        %   'stopMode'        (scalar) Use 1 to stop immediately or 2 to
        %                              stop in a controlled manner.
        %
        function stopCommand(obj, channelIdentity, stopMode)
            if(~isempty(obj.serialConnection))
                % Format is ([0x65-0x04][uint16 channel][uint16 stopMode][0x00-0x00])
                commandStructure = uint8([101, 4, channelIdentity, stopMode, 0, 0]);
                % Sends
                fwrite(obj.serialConnection, commandStructure, 'uint8');
            else
                fprintf('Error_AxisController: No Connection!');
            end
        end
        
        %
        % Description:
        %   Requests the current location of the given motor.
        %   The returned value is the distance in encoder units?.
        %
        % Parameters:
        %   'channelIdentity' (scalar) The target motor. Either 0, 1, or 2.
        %
        function value = queryPosition(obj, channelIdentity)
            if(~isempty(obj.serialConnection))
                % Format is ([0x0A-0x04][uint8 channel][0x00-0x00-0x00])
                commandStructure = uint8([10, 4, channelIdentity, 0, 0, 0]);
                fwrite(obj.serialConnection, commandStructure, 'uint8');
                % Response format is ([0x0B-0x04-0x06-0x00-0x00-0x00][uint16 channel][int32 position])
                response = fread(obj.serialConnection, 12);
                if(isempty(response) || (sum(response(1:6, 1) ~= uint8([11; 4; 6; 0; 0; 0])) == 6))
                    value = -1; 
                else
                    value = int32(bitor(bitor(bitor(bitshift(response(9, 1), 0), bitshift(response(10, 1), 8)), bitshift(response(11, 1), 16)), bitshift(response(12, 1), 24)));
                end
            else
                value = -1;
                fprintf('Error_AxisController: No Connection!');
            end
        end
        
        %
        % Description:
        %   Sets the given motor to the location specified 
        %   by distance.
        %
        % Parameters:
        %   'channelIdentity' (scalar) The target motor. Either 0, 1, or 2. 
        %   'distance'        (scalar) Position in encoder marks to travel.
        %
        function goToPosition(obj, channelIdentity, distance)
            if(~isempty(obj.serialConnection))
                % Format is ([0x53, 0x04, 0x06, 0x00, 0x00, 0x00][uint8 channel][int32 position])
                commandStructure = uint8([83, 4, 6, 0, 0, 0, channelIdentity, typecast(int32(distance), 'uint8')]);
                fwrite(obj.serialConnection, commandStructure, 'uint8');
                pause(obj.DELAYTIME);
            else
                fprintf('Error_AxisController: No Connection!');
            end
        end
        
        %
        % Description:
        %   Determines whether the motor is still working.
        %
        % Parameters:
        %   'channelIdentity' (scalar) The target motor. Either 0, 1, or 2. 
        %
        % Returns:
        %   The motor position in encoder units. Returns -1 if there was 
        %   a communications failure.
        %
        function value = queryStatus(obj, channelIdentity)
            if(~isempty(obj.serialConnection))
                % Format is ([0x80-0x04][uint8 channel][0x00-0x00-0x00])
                commandStructure = uint8([50, 4, channelIdentity, 0, 0, 0]);
                fwrite(obj.serialConnection, commandStructure, 'uint8');
                % Response is TODO
                response = fread(obj.serialConnection, 17);
                %if(response(1:6) ~= uint8([10, 4, 6, 0, 0, 0]))
                %    value = -1; % TODO better response
                %else
                %    value = int32(response(9:12));
                %end
                value = response;
            else
                fprintf('Error_AxisController: No Connection!');
                value = -1;
            end
        end
    end
end