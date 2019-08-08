%This script scans an patterns OCT Volume. Uses multiple depths to extend depth of focus
%I assume that prior to running this script, user placed focuse at the top
%of the tissue.

%Pre
if (~isRunningOnJenkins())
	clear;
end
currentFileFolder = [fileparts(mfilename('fullpath')) '\'];

%% Inputs 
outputFolder = 'output'; %This will be override if running with Jenkins
outputFolder = [outputFolder '\'];

%OCT Scan Defenitions (scan size (scan is centered along (0,0))
config.scan.rangeX = 1; %[mm]
config.scan.rangeY = 1; %[mm]
config.scan.nPixelsX = 100; %How many pixels in x direction <--
config.scan.nPixelsY = 100; %How many pixels in y direction <--
%Overview of the entire area
config.overview.rangeAll = 6;%[mm] x=y
config.overview.range = config.scan.rangeX;%[mm] x=y
config.overview.nPixels = max(config.scan.nPixelsX/20,50); %same for x and y
config.isRunOverview = false; %Do you want to scan overview volume? When running on Jenkins, will allways run overview 
config.BScanAvg = 1;

%Photobleaching defenitions
    %Line placement (vertical - up/down, horizontal - left/right)
	config.base = 100/1000; %base seperation [mm]
    config.vLinePositions = base*[-1 0 3]; %[mm] 
    config.hLinePositions = base*[-1 0 2]; %[mm] 

    config.exposurePerLine = 30; %[sec]
    config.passes = 2;
    config.lineLength = 2; %[mm]
    
%Probe defenitions
    config.octProbePath = [currentFileFolder 'Probe - Olympus 10x.ini'];
    %Define scale and offset for fast & slow axis calibration
    config.offsetX = 0/1000; %[mm]
    config.offsetY = 0; %[mm]
    config.scaleX =  0.99421;
    config.scaleY =  1;

%Depth Defenitions
%We assume stage starting position is at the top of the tissue.
%z defenitions below are compared to starting position
%+z is deeper
config.zToPhtobleach = -300; %[um] this parameter is ignored if running from jenkins - will assume provided by jenkins
config.zToScan = (-190:15:500)-5; %[um]

%Tissue Defenitions
config.tissueRefractiveIndex = 1.4;

%Tickmarks (if required)
config.isDrawTickmarks = false;
config.tickmarksX0 = [-0.3, 0.25];
config.tickmarksY0 = [-0.25,0.25];

%% Initialize
fprintf('%s Initialzing\n',datestr(datetime));
disp('We assume laser is focused on the top of the tissue interface');
disp('Otherwise abort now');
if ~exist(config.octProbePath,'file')
	error(['Cannot find probe file: ' config.octProbePath]);
end
ThorlabsImagerNETLoadLib(); %Init library
ThorlabsImagerNET.ThorlabsImager.yOCTScannerInit(config.octProbePath); %Init OCT
z0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('z'); %Init stage
x0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('x'); %Init stage
y0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('y'); %Init stage

isExecutingOnJenkins = isRunningOnJenkins();
ExecutionStartTime = datestr(now());

if (isRunningOnJenkins())
    config.outputFolder = outputFolder_; %Set by Jenkins
    config.zToPhtobleach = zToPhtobleach_; %Set by Jenkins
    config.isDrawTickmarks = isDrawTickmarks_; %Set by Jenkins
	config.isRunOverview = true;	
end
mkdir(outputFolder);

%Scan one silce where we photobleaching
config.zToScan = [config.zToPhtobleach config.zToScan];

%Overview center positons
config.overview.gridXc = (-config.overview.rangeAll/2+config.overview.range/2):config.overview.range:(config.overview.rangeAll/2-config.overview.range/2);
config.overview.gridYc = (-config.overview.rangeAll/2+config.overview.range/2):config.overview.range:(config.overview.rangeAll/2-config.overview.range/2);
[config.overview.gridXcc,config.overview.gridYcc] = meshgrid(config.overview.gridXc,config.overview.gridYc);
config.overview.gridXcc = config.overview.gridXcc(:);
config.overview.gridYcc = config.overview.gridYcc(:);

%Create a config structure
%s = who;
%config = [];
%for i=1:length(s)
%    eval(sprintf('config.%s = %s;',s{i},s{i}));
%end

%% Photobleach
ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('z',z0+config.zToPhtobleach/1000); %Movement [mm]

fprintf('%s Put on safety glasses. photobleaching in ...',datestr(datetime));
for i=5:-1:1
    fprintf(' %d',i);
    pause(1);
end
fprintf('\n');

ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(true); %Switch on
for i=1:length(config.vLinePositions)
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        config.vLinePositions(i),-config.lineLength/2, ... Start X,Y
        config.vLinePositions(i),+config.lineLength/2, ... End X,Y
        config.exposurePerLine,config.passes); 
end

for i=1:length(config.hLinePositions)
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        -config.lineLength/2,config.hLinePositions(i), ... Start X,Y
        +config.lineLength/2,config.hLinePositions(i), ... End X,Y
        config.exposurePerLine,config.passes); 
end
ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(false); %Switch off

if (config.isDrawTickmarks)
    PhotobleachTickmarks_Thorlabs(config.tickmarksX0,config.tickmarksY0,config.vLinePositions,config.hLinePositions,[outputFolder '\01 OCT Scan and Pattern Log\']);
end

disp('Done');

%% Scan Volume
mkdir([outputFolder '\Volume\']);
for i=1:length(config.zToScan)
    fprintf('%s Scanning Volume %02d of %d\n',datestr(datetime),i,length(config.zToScan));
    
    %Move to position
    ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('z',z0+config.zToScan(i)/1000); %Movement [mm]
    
    %Scan
    s = sprintf('%s\\Volume\\Pos%02d\\',outputFolder,i);
    ThorlabsImagerNET.ThorlabsImager.yOCTScan3DVolume(...
        config.offsetX,config.offsetY, ... centerX, centerY [mm]
        config.scan.rangeX*config.scaleX, config.scan.rangeY*config.scaleY, ... rangeX,rangeY [mm]
        0,       ... rotationAngle [deg]
        config.scan.nPixelsX,config.scan.nPixelsY, ... SizeX,sizeY [# of pixels]
        config.BScanAvg,       ... B Scan Average
        s ... Output directory, make sure it exists before running this function
        );
		
	if (i==1)
		%Figure out which OCT System are we scanning in
		a =dir(s);
		names = {a.name}; names([a.isdir]) = [];
		nm = names{round(end/2)};
		if (contains(lower(nm),'ganymede'))
			config.OCTSystem = 'Ganymede';
		else
			config.OCTSystem = 'NA';
		end
	end
end
ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('z',z0); %Bring stage to 0

%% Scan Overview
if (config.isRunOverview)
	fprintf('%s Scanning Overview\n',datestr(datetime));
	mkdir([outputFolder '\Overview\']);
	for q = 1:length(config.overview.gridXcc)
		fprintf('Imaging at xc=%.1f,yc=%.1f (%d of %d)...\n',...
			config.overview.gridXcc(q),config.overview.gridYcc(q),q,length(config.overview.gridXcc));

		%Move
		ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('x',...
			 x0 + config.overview.gridXcc(q)... Movement [mm]
			);
		ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('y',...
			 y0 + config.overview.gridYcc(q)... Movement [mm]
			);
		
		%Scan
		folder = [outputFolder sprintf('Overview\\Overview%02d',q)];
		ThorlabsImagerNET.ThorlabsImager.yOCTScan3DVolume(...
			config.offsetX,config.offsetY,config.overview.range*config.scaleX,config.overview.range*config.scaleY, ...centerX,centerY,rangeX,rangeY [mm]
			0,       ... rotationAngle [deg]
			config.overview.nPixels,config.overview.nPixels,   ... SizeX,sizeY [# of pixels]
			1,       ... B Scan Average
			folder   ... Output directory, make sure it exists before running this functio
			);
	end

	%Return home
	ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('x',x0);
	ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('y',y0);
end

%% Finalize
fprintf('%s Finalizing\n',datestr(datetime));
ThorlabsImagerNET.ThorlabsImager.yOCTScannerClose(); %Close scanner
    
%Save scan configuration parameters
config
awsWriteJSON(config, [outputFolder 'ScanConfig.json']);