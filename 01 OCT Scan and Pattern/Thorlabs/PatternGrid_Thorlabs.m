%This script scans an patterns OCT Volume. Uses multiple depths to extend depth of focus
%I assume that prior to running this script, user placed focuse at the top
%of the tissue.
clear;
currentFileFolder = [fileparts(mfilename('fullpath')) '\'];

%Line placement (vertical - up/down, horizontal - left/right)
vLinePositions = (-2000:100:2000)/1000; %[mm]
hLinePositions = (-2000:200:2000)/1000; %[mm]
%vLinePositions = [-100 0 100]/1000;
%hLinePositions = [-100 0 100]/1000;

%Photobleaching defenitions
exposurePerLine = 45; %[sec]
passes = 3;
lineLength = 3; %[mm]
    
%Probe defenitions
octProbePath = [currentFileFolder 'Probe - Olympus 10x 2019_07_17.ini'];
%Define scale and offset for fast & slow axis calibration
offsetX = 0; %[mm]
offsetY = 0; %[mm]
scaleX =  1;
scaleY =  1;

%% Initialize
fprintf('%s Initialzing\n',datestr(datestr(datetime)));
ThorlabsImagerNETLoadLib(); %Init library
ThorlabsImagerNET.ThorlabsImager.yOCTScannerInit(octProbePath); %Init OCT

%% Photobleach

fprintf('%s Put on safety glasses. photobleaching in ...',datestr(datetime));
for i=5:-1:1
    fprintf(' %d',i);
    pause(1);
end
fprintf('\n');

%Turn laser on

for i=1:length(vLinePositions)
    fprintf('%s vline #%d/%d. %.1f more minutes to go\n',datestr(datestr(datetime)),i,length(vLinePositions),(length(vLinePositions)-i+1+length(hLinePositions))*exposurePerLine/60)
    
    disp('Scanning On');
    ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(true);
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        vLinePositions(i),-lineLength/2, ... Start X,Y
        vLinePositions(i),+lineLength/2, ... End X,Y
        exposurePerLine,passes);
    ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(false);
    disp('Scanning Off');
    
    pause(2);
end

for i=1:length(hLinePositions)
    fprintf('%s hline #%d/%d. %.1f more minutes to go\n',datestr(datestr(datetime)),i,length(vLinePositions),(length(hLinePositions)-i+1)*exposurePerLine/60)
    
    disp('Scanning On');
    ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(true);
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        -lineLength/2,hLinePositions(i), ... Start X,Y
        +lineLength/2,hLinePositions(i), ... End X,Y
        exposurePerLine,passes); 
    ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(false);
    disp('Scanning Off');
    
    pause(2);
end

%Turn laser off
ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(false);
disp('Laser Off. Done');

%% Finalize
fprintf('%s Finalizing\n',datestr(datetime));
ThorlabsImagerNET.ThorlabsImager.yOCTScannerClose(); %Close scanner