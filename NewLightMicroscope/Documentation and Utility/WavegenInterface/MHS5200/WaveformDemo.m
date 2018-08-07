%
% This script demonstrates control of the MHS5200A arbitrary waveform
% generator using built in Matlab serial commands. Please see the function
% file for further details.
%

%% The Program
wavegen = MHS5200;
ans = wavegen.serialConnected()
%{
out = instrfind()
s = serial('COM4');
set(s,'BaudRate', 57600);
fopen(s);
fprintf(s,''); % Clears old
fprintf(s, 'r1c'); % Requests firmware
fscanf(s) % Should return 3.23, 'r1c323'
fprintf(s, 'r2c'); % Requests P/N
fscanf(s) % Should return last digits of P/N
fprintf(s, 'r0c'); % Requests model number
fscanf(s) % Should return last digits of model number, 'r0c521'
fclose(s);
%}

