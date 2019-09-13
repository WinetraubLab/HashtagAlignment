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

%OCT scan defenitions (scan is centered along (0,0)
config.scan.rangeX = 1; %[mm]
config.scan.rangeY = 1; %[mm]
config.scan.nPixelsX = 1000; %How many pixels in x direction
config.scan.nPixelsY = 1000; %How many pixels in y direction
config.scan.nBScanAvg = 1;

%Depth Defenitions
%We assume stage starting position is at the top of the tissue.
%z defenitions below are compared to starting position
%+z is deeper
config.zToPhtobleach = -300*1e-3; %[mm] this parameter is ignored if running from jenkins - will assume provided by jenkins
config.zToScan = ((-190:15:500)-5)*1e-3; %[mm]

%Tissue Defenitions
config.tissueRefractiveIndex = 1.4;

%Overview of the entire area
config.isRunOverview = false; %Do you want to scan overview volume? When running on Jenkins, will allways run overview 
config.overview.rangeAllX = 6;%[mm] Total tiles range
config.overview.rangeAllY = 5;%[mm] Total tiles range
config.overview.range = config.scan.rangeX;%[mm] x=y range of each tile
config.overview.nPixels = max(config.scan.nPixelsX/20,50); %same for x and y, number of pixels in each tile
config.overview.nZToScan = 1; %How many different depths to scan in overview to provide coverage

%Photobleaching defenitions
%Line placement (vertical - up/down, horizontal - left/right)
base = 100/1000; %base seperation [mm]
%config.vLinePositions = base*[-1 0 3]; %[mm] 
%config.hLinePositions = base*[-1 0 2]; %[mm] 
config.vLinePositions = base*[-4  0 1 3]; %[mm] 
config.hLinePositions = base*[-3 -2 1 3]; %[mm] 
config.photobleach.exposurePerLine_sec = 30; %[sec]
config.photobleach.passes = 2;
config.photobleach.lineLength = 2; %[mm]
    
%Probe defenitions
config.octProbePath = [currentFileFolder 'Probe - Olympus 10x.ini'];
%Define scale and offset for fast & slow axis calibration
config.offsetX = 0/1000; %[mm]
config.offsetY = 0; %[mm]
config.scaleX =  0.99421;
config.scaleY =  1;

%Tickmarks (if required)
config.isDrawTickmarks = false;
config.tickmarksX0 = [-0.3, 0.25];
config.tickmarksY0 = [-0.25,0.25];

%Orientation dot
config.isDrawTheDot = false;
config.theDotX = -config.photobleach.lineLength/2;
config.theDotY = +config.photobleach.lineLength/2;

%% Inputs from Jenkins
isExecutingOnJenkins = isRunningOnJenkins();
if (isRunningOnJenkins())
    outputFolder = outputFolder_; %Set by Jenkins
    config.zToPhtobleach = zToPhtobleach_; %Set by Jenkins
    config.isDrawTickmarks = isDrawTickmarks_; %Set by Jenkins
    config.isDrawTheDot = isDrawTickmarks_;
	config.isRunOverview = true;	
	
	if (exist('isDebugFastMode_','var') && isDebugFastMode_ == true) %Debug mode, make a faster scan
		disp('Entering debug mode!');
		config.scan.nPixelsX = 100; 
		config.scan.nPixelsY = 100; 
		config.overview.rangeAllX = 2;
        config.overview.rangeAllY = 1;
		config.vLinePositions = config.base*[0]; %[mm] 
		config.hLinePositions = config.base*[0]; %[mm] 
        config.overview.nZToScan = 1;
		config.exposurePerLine_sec = 10; %sec
		config.zToScan = [config.zToScan(1:3) 0]; %Reduce number of Z scans
	end
end

if exist('gitBranch_','var')
    config.gitBranchUsedToScan = gitBranch_; %Save which git branch was used to scan
else
    config.gitBranchUsedToScan = 'unknown';
end

%% Add preprogramed config parameter

%Input check
if (sum(config.zToScan == 0) == 0)
	error('zToScan does not contain focus (z=0) that will cause problems down the road, please adjust');
end

config.whenWasItScanned = datestr(now());
config.version = 2; %Version of this JSON file

%Scan one silce where we photobleaching
config.zToScan = unique([config.zToPhtobleach config.zToScan]);

%% Initialize Hardware
fprintf('%s Initialzing\n',datestr(datetime));
disp('We assume laser is focused on the top of the tissue interface');
disp('Otherwise abort now');
if ~exist(config.octProbePath,'file')
	error(['Cannot find probe file: ' config.octProbePath]);
end
ThorlabsImagerNETLoadLib(); %Init library
z0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('z'); %Init stage
x0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('x'); %Init stage
y0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('y'); %Init stage

%Make dirs for output and log
if ~exist(outputFolder,'dir')
	mkdir(outputFolder);
end
logFolder = [outputFolder '..\Log\01 OCT Scan and Pattern\'];
if ~exist(logFolder,'dir')
	mkdir(logFolder);
end
%% Photobleach
ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('z',z0+config.zToPhtobleach); %Movement [mm]

fprintf('%s Put on safety glasses. photobleaching in ...',datestr(datetime));
for i=5:-1:1
    fprintf(' %d',i);
    pause(1);
end
fprintf('\n');

ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(true); %Switch on
for i=1:length(config.vLinePositions)
	fprintf('%s Photobleaching V Line # %d / %d\n',datestr(datetime),i,length(config.vLinePositions));
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        config.vLinePositions(i),-config.photobleach.lineLength/2, ... Start X,Y
        config.vLinePositions(i),+config.photobleach.lineLength/2, ... End X,Y
        config.photobleach.exposurePerLine_sec,config.photobleach.passes); 
end

for i=1:length(config.hLinePositions)
	fprintf('%s Photobleaching H Line # %d / %d\n',datestr(datetime),i,length(config.hLinePositions));
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        -config.photobleach.lineLength/2,config.hLinePositions(i), ... Start X,Y
        +config.photobleach.lineLength/2,config.hLinePositions(i), ... End X,Y
        config.photobleach.exposurePerLine_sec,config.photobleachs.passes); 
end

if (config.isDrawTickmarks)
    PhotobleachTickmarks_Thorlabs(config.tickmarksX0,config.tickmarksY0,config.vLinePositions,config.hLinePositions,logFolder);
end

if (config.isDrawTheDot)
    dl = 0.1; %[mm]
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        config.theDotX-dl/2,config.theDotY, ... Start X,Y
        config.theDotX+dl/2,config.theDotY, ... End X,Y
        2*dl*config.exposurePerLine_sec/config.lineLength,config.passes);  
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        config.theDotX,config.theDotY-dl/2, ... Start X,Y
        config.theDotX,config.theDotY+dl/2, ... End X,Y
        2*dl*config.photobleach.exposurePerLine_sec/config.lineLength,config.photobleach.passes); 
end

ThorlabsImagerNET.ThorlabsImager.yOCTTurnLaser(false); %Switch off
disp('Done');

%% Scans

%Volume
volumeOutputFolder = [outputFolder '\Volume\'];
mkdir(volumeOutputFolder);
config.scan.scanParameters = yOCTScanTile (...
    volumeOutputFolder, ...
    'octProbePath', config.octProbePath, ...
    'tissueRefractiveIndex', config.tissueRefractiveIndex, ...
    'xOffset', config.offsetX, ...
    'yOffset', config.offsetY, ... 
    'xRange', config.scan.rangeX * config.scaleX, ...
    'yRange', config.scan.rangeY * config.scaleY, ...
    'nXPixels', config.scan.nPixelsX, ...
    'nYPixels', config.scan.nPixelsY, ...
    'nBScanAvg', config.scan.nBScanAvg, ...
    'zDepts',    config.zToScan, ... [mm]
    'v',true  ...
    );

%Overview
if (config.isRunOverview)
	fprintf('%s Scanning Overview\n',datestr(datetime));
    
    overviewOutputFolder = [outputFolder '\Overview\'];
    %Overview center positons
    gridXc = (-config.overview.rangeAllX/2+config.overview.range/2):config.overview.range:(config.overview.rangeAllX/2-config.overview.range/2);
    gridYc = (-config.overview.rangeAllY/2+config.overview.range/2):config.overview.range:(config.overview.rangeAllY/2-config.overview.range/2);
    
    z = config.zToScan;
    z(z<0) = []; %Overview should be scanned in tissue 
    z = z(round(linspace(1,length(z),min(config.overview.nZToScan,length(z)))));
    
    mkdir(overviewOutputFolder);
    config.overview.scanParameters = yOCTScanTile (...
        overviewOutputFolder, ...
        'octProbePath', config.octProbePath, ...
        'tissueRefractiveIndex', config.tissueRefractiveIndex, ...
        'xOffset', 0, ...
        'yOffset', 0, ... 
        'xRange', config.overview.range, ...
        'yRange', config.overview.range, ...
        'nXPixels', config.overview.nPixels, ...
        'nYPixels', config.overview.nPixels, ...
        'nBScanAvg', 1, ...
        'zDepts',    z, ... [mm]
        'xCenters', gridXc ,...
        'yCenters', gridYc ,...
        'v',true  ...
        );
end

%% Finalize
fprintf('%s Finalizing\n',datestr(datetime));
    
%Save scan configuration parameters
if exist([outputFolder 'ScanConfig.json'],'file')
	%Load Config first, dont override it
	cfg = awsReadJSON([outputFolder 'ScanConfig.json']);
	fns = fieldnames(cfg);
	for i=1:length(fns)
		eval(['config.' fns{i} ' = cfg.' fns{i} ';']);
	end
end
config
config.photobleach
config.scan
config.overview

%Remove fields that are not in use again, their information is redundent
config.scan = rmfield(config.scan,{'nPixelsX','nPixelsY','nBScanAvg'});
config.overview = rmfield(config.overview,{'range','nPixels','nBScanAvg','nZToScan','rangeAllX','rangeAllY'});
config = rmfield(config,{'octProbePath','tissueRefractiveIndex','zDepts'});

%Save
awsWriteJSON(config, [outputFolder 'ScanConfig.json']);