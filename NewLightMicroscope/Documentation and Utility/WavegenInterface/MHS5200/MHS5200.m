classdef MHS5200
    % MHS5200 class to interface with waveform generator
    %   Interfaces with the MHS5200 waveform generator over
    %   serial.
    
    % TODO Check serial works, finish all functions
    properties (Access = private)
        serialConnection;
    end
    
    properties (Constant)
        MAX_CHANNELS = 2;         % Two channel generator
        MAX_FREQUENCY = 6e6;      % Conservative 6 MHZ max
        SERIAL_BAUD = 57600;      % Baud rate used
        SERIAL_BITS = 8;          % Number of bits per message
        SERIAL_PARITY = 'none';   % Do not use parity
        SERIAL_TERMINATOR = '\n'; % Uses /n or CRLF
        SERIAL_STOPBIT = 1;       % From sheet
    end
    
    methods
        function obj = MHS5200()
            % Tries to find a valid serial port
            serialOptions = instrfind('Status', 'open')
            obj.serialConnection = 0;
            for index = 1:length(serialOptions)
                obj.serialConnection = serial(serialOptions(index));
                obj.serialConnection.BaudRate = obj.SERIAL_BAUD;
                obj.serialConnection.DataBits = obj.SERIAL_BITS;
                obj.serialConnection.FlowControl = 'none'; % TODO
                obj.serialConnection.Parity = obj.SERIAL_PARITY;
                
                % Tests to see if this is a waveform generator
                fclose(obj.serialConnection);
                fopen(obj.serialConnection);
                fprintf(obj.serialConnection, ':s1w1');
                if(fscanf(obj.serialConnection) == 'ok')
                    break
                end
                fclose(obj.serialConnection);
                delete(obj.serialConnection);
                obj.serialConnection = 0;
            end
        end
        
        % 1 if connected, 0 if not connected
        function bool = serialConnected(obj)
            bool = obj.serialConnection ~= 0;
        end
        
        % Function to set 'channel' with 'frequency', does not alter 
        % waveform. Returns 1 if sucessful. 
        function bool = setChannelFrequency(obj,frequency, channel)
            bool = 0;
            % Verifies input
            if(~(isPIntegerInput(frequency) && isPIntegerInput(channel) && isPIntegerInput(frequency) && (frequency <= FREQUENCY_MAX && (channel <= CHANNEL_MAX))))
                error('Invalid inputs for setting MHS5200 frequency');
            elseif(~serialConnected()) % Verifies connection
                error('No active device');
            else
                % Sends data
                fopen(obj.serialConnection);
                fprintf(obj.serialConnection, ':s%d%d', [channel, frequency]);
                % Waits for reception
            end
        end
    end
    
    methods (Access = private)
        % Checks that the given input is a positive integer
        function bool = isPIntegerInput(obj, input)
            bool = 0;
            if(isnumeric(input) && isscalar(input) && (floor(input) == input) && (input >= 0))  
                bool = 1;
            end
        end
    end
end

