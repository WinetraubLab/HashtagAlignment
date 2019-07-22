%This script scans an patterns OCT Volume. Uses multiple depths to extend depth of focus
%I assume that prior to running this script, user placed focuse at the top
%of the tissue.
clear;
currentFileFolder = [fileparts(mfilename('fullpath')) '\'];
%%TBD - ADD INPUT DEPTH OF PHOTBOLEACH ABOVE SURFACE

%% Inputs 
outputFolder = '.'; %This will be override if running with Jenkins
outputFolder = [outputFolder '\'];

%OCT Scan Defenitions (scan size (scan is centered along (0,0))
scan.rangeX = 1; %[mm]
scan.rangeY = 1; %[mm]
scan.nPixelsX = 1000; %How many pixels in x direction
scan.nPixelsY = 1000; %How many pixels in y direction
%Overview of the entire area
overview.range = 4;%[mm] x=y
overview.nPixels = 100; %same for x and y
BScanAvg = 1;

%Photobleaching defenitions
    %Line placement (vertical - up/down, horizontal - left/right)
    vLinePositions = [-50 0 100]; %[microns]
    hLinePositions = [-50 0 150]; %[microns]

    exposurePerLine = 30; %[sec]
    passes = 1;
    lineLength = 2; %[mm]
    
%Probe defenitions
    octProbePath = [currentFileFolder 'Probe - Olympus 10x 2019_07_17.ini'];
    %Define scale and offset for fast & slow axis calibration
    offsetX = 0; %[mm]
    offsetY = 0; %[mm]
    scaleX =  1;
    scaleY =  1;

%Depth Defenitions
%We assume stage starting position is at the top of the tissue.
%z defenitions below are compared to starting position
zToPhtobleach = -300; %[um]
zToScan = -100:15:500; %[um]

%% Initialize
fprintf('%s Initialzing\n',datetime);
disp('We assume laser is focused on the top of the tissue interface');
disp('Otherwise abort now');
ThorlabsImagerNETLoadLib(); %Init library
ThorlabsImagerNET.ThorlabsImager.yOCTScannerInit(octProbePath); %Init OCT
ThorlabsImagerNET.ThorlabsImager.yOCTStageInit(); %Init stage

if (isRunningOnJenkins())
    outputFolder = [currentFileFolder 'output\'];
end
mkdir(outputFolder);

%Create a config structure
s = who;
config = [];
for i=1:length(s)
    eval(sprintf('config.%s = %s;',s{i},s{i}));
end

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

%% Scan Overview
fprintf('%s Scanning Overview\n',datetime);
mkdir([outputFolder 'overview']);
ThorlabsImagerNET.ThorlabsImager.yOCTScan3DVolume(...
    -overview.range/2,-overview.range/2, ... startX, startY
    overview.range,overview.range, ... rangeX,rangeY [mm]
	0,       ... rotationAngle [deg]
    overview.nPixels,overview.nPixels, ... SizeX,sizeY [# of pixels]
    BScanAvg,       ... B Scan Average
    [outputFolder 'overview'] ... Output directory, make sure it exists before running this function
    );

%% Scan Volume
for i=1:length(zToScan)
    fprintf('%s Scanning Volume %d of %d\n',datetime,i,length(zToScan));
    
    %Move to position
    ThorlabsImagerNET.ThorlabsImager.yOCTStageSetZPosition(zToScan(i)/1000); %Movement [mm]
    
    %Scan
    s = sprintf('%spos %02d',outputFolder);
    mkdir(s);
    ThorlabsImagerNET.ThorlabsImager.yOCTScan3DVolume(...
        -scan.rangeX/2*scaleX + offsetX, -scan.rangeY/2*scaleY + offsetY, ... startX, startY
        scan.rangeX*scaleX, scan.rangeX*scaleY, ... rangeX,rangeY [mm]
        0,       ... rotationAngle [deg]
        scan.nPixelsX,scan.nPixelsY, ... SizeX,sizeY [# of pixels]
        1,       ... B Scan Average
        s ... Output directory, make sure it exists before running this function
        );

end

%% Finalize
fprintf('%s Finalizing\n',datetime);
ThorlabsImagerNET.ThorlabsImager.yOCTStageSetZPosition(0); %Bring stage to 0
ThorlabsImagerNET.ThorlabsImager.yOCTScannerClose(); %Close scanner
    
%Save scan configuration parameters
txt = jsonencode(config);
txt = strrep(txt,'"',[newline '"']);
txt = strrep(txt,[newline '":'],'":');
txt = strrep(txt,[':' newline '"'],':"');
txt = strrep(txt,[newline '",'],'",');
fid = fopen([outputFolder 'ScanConfig.json'],'w');
fprintf(fid,'%s',txt);
fclose(fid);
