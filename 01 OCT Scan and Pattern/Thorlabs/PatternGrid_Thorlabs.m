%This script scans an patterns OCT Volume. Uses multiple depths to extend depth of focus
%I assume that prior to running this script, user placed focuse at the top
%of the tissue.
clear;

%Line placement (vertical - up/down, horizontal - left/right)
vLinePositions = -2000:100:2000; %[microns]
hLinePositions = -2000:200:2000; %[microns]

%Photobleaching defenitions
exposurePerLine = 30*2; %[sec]
passes = 1;
lineLength = 2*2; %[mm]
    
%Probe defenitions
octProbePath = [currentFileFolder 'Probe - Olympus 10x 2019_07_17.ini'];
%Define scale and offset for fast & slow axis calibration
offsetX = 0; %[mm]
offsetY = 0; %[mm]
scaleX =  1;
scaleY =  1;

%% Initialize
fprintf('%s Initialzing\n',datetime);
ThorlabsImagerNETLoadLib(); %Init library
ThorlabsImagerNET.ThorlabsImager.yOCTScannerInit(octProbePath); %Init OCT

%% Photobleach
ThorlabsImagerNET.ThorlabsImager.yOCTStageSetZPosition(zToPhtobleach/1000); %Movement [mm]

fprintf('%s Put on safety glasses. photobleaching in ...',datetime);
for i=5:-1:1
    fprintf(' %d',i);
    pause(1);
end
fprintf('\n');

for i=1:length(vLinePositions)
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        vLinePositions(i),-lineLength/2, ... Start X,Y
        vLinePositions(i),+lineLength/2, ... End X,Y
        exposurePerLine,passes); 
end

for i=1:length(hLinePositions)
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        -lineLength/2,hLinePositions(i), ... Start X,Y
        +lineLength/2,hLinePositions(i), ... End X,Y
        exposurePerLine,passes); 
end

disp('Done');

%% Finalize
fprintf('%s Finalizing\n',datetime);
ThorlabsImagerNET.ThorlabsImager.yOCTScannerClose(); %Close scanner