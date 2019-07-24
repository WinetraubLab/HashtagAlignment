%This script scans an patterns OCT Volume. Uses multiple depths to extend depth of focus
%I assume that prior to running this script, user placed focuse at the top
%of the tissue.
clear;
currentFileFolder = [fileparts(mfilename('fullpath')) '\'];

%% Inputs 
outputFolder = 'output'; %This will be override if running with Jenkins
outputFolder = [outputFolder '\'];

%OCT Scan Defenitions (scan size (scan is centered along (0,0))
scan.rangeX = 1; %[mm]
scan.rangeY = 1; %[mm]
scan.nPixelsX = 1000; %How many pixels in x direction
scan.nPixelsY = 1000; %How many pixels in y direction
%Overview of the entire area
overview.rangeAll = 4;%[mm] x=y
overview.range = scan.rangeX;%[mm] x=y
overview.nPixels = scan.nPixelsX/10; %same for x and y
BScanAvg = 1;

%Photobleaching defenitions
    %Line placement (vertical - up/down, horizontal - left/right)
    vLinePositions = [-50 0 100]/1000; %[mm]
    hLinePositions = [-50 0 150]/1000; %[mm]

    exposurePerLine = 30; %[sec]
    passes = 1;
    lineLength = 2; %[mm]
    
%Probe defenitions
    octProbePath = [currentFileFolder 'Probe - Olympus 10x.ini'];
    %Define scale and offset for fast & slow axis calibration
    offsetX = 0; %[mm]
    offsetY = 0; %[mm]
    scaleX =  1;
    scaleY =  1;

%Depth Defenitions
%We assume stage starting position is at the top of the tissue.
%z defenitions below are compared to starting position
%+z is deeper
zToPhtobleach = -300; %[um] this parameter is ignored if running from jenkins - will assume provided by jenkins
zToScan = (-100:15:500)-5; %[um]

%% Initialize
fprintf('%s Initialzing\n',datestr(datetime));
disp('We assume laser is focused on the top of the tissue interface');
disp('Otherwise abort now');
ThorlabsImagerNETLoadLib(); %Init library
ThorlabsImagerNET.ThorlabsImager.yOCTScannerInit(octProbePath); %Init OCT
z0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('z'); %Init stage
x0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('x'); %Init stage
y0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('y'); %Init stage

if (isRunningOnJenkins())
    outputFolder = [currentFileFolder 'output\'];
    zToPhtobleach = zToPhtobleach_; %Set by Jenkins
end
mkdir(outputFolder);

%Overview center positons
overview.gridXc = (-overview.rangeAll/2+overview.range/2):overview.range:(overview.rangeAll/2-overview.range/2);
overview.gridYc = (-overview.rangeAll/2+overview.range/2):overview.range:(overview.rangeAll/2-overview.range/2);
[overview.gridXcc,overview.gridYcc] = meshgrid(overview.gridXc,overview.gridYc);
overview.gridXcc = overview.gridXcc(:);
overview.gridYcc = overview.gridYcc(:);

%Create a config structure
s = who;
config = [];
for i=1:length(s)
    eval(sprintf('config.%s = %s;',s{i},s{i}));
end

%% Photobleach
ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('z',z0+zToPhtobleach/1000); %Movement [mm]

fprintf('%s Put on safety glasses. photobleaching in ...',datestr(datetime));
for i=5:-1:1
    fprintf(' %d',i);
    pause(1);
end
fprintf('\n');

ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(true); %Switch on
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
ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(false); %Switch off

disp('Done');

%% Scan Volume
for i=1:length(zToScan)
    fprintf('%s Scanning Volume %02d of %d\n',datestr(datetime),i,length(zToScan));
    
    %Move to position
    ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('z',z0+zToScan(i)/1000); %Movement [mm]
    
    %Scan
    s = sprintf('%s\\Volume\\Pos%02d\\',outputFolder,i);
    ThorlabsImagerNET.ThorlabsImager.yOCTScan3DVolume(...
        offsetX,offsetY, ... centerX, centerY [mm]
        scan.rangeX*scaleX, scan.rangeX*scaleY, ... rangeX,rangeY [mm]
        0,       ... rotationAngle [deg]
        scan.nPixelsX,scan.nPixelsY, ... SizeX,sizeY [# of pixels]
        1,       ... B Scan Average
        s ... Output directory, make sure it exists before running this function
        );

end

%% Scan Overview
fprintf('%s Scanning Overview\n',datestr(datetime));
ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('z',z0); %Bring stage to 0

for q = 1:length(overview.gridXcc)
    fprintf('Imaging at xc=%.1f,yc=%.1f (%d of %d)...\n',...
        overview.gridXcc(q),overview.gridYcc(q),q,length(overview.gridXcc));

	%Move
    ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('x',...
         x0 + overview.gridXcc(q)... Movement [mm]
		);
    ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('y',...
         y0 + overview.gridYcc(q)... Movement [mm]
		);
    
	%Scan
	folder = [outputFolder sprintf('Overview\\Overview%02d',q)];
    ThorlabsImagerNET.ThorlabsImager.yOCTScan3DVolume(...
        offsetX,offsetY,overview.range*scaleX,overview.range*scaleX, ...centerX,centerY,rangeX,rangeY [mm]
        0,       ... rotationAngle [deg]
        overview.nPixels,overview.nPixels,   ... SizeX,sizeY [# of pixels]
        1,       ... B Scan Average
        folder   ... Output directory, make sure it exists before running this functio
        );
end

%% Finalize
fprintf('%s Finalizing\n',datestr(datetime));
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
