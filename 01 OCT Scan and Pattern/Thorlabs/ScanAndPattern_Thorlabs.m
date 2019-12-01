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
config.volume.isScanEnabled = true; %Enable/Disable regular scan
config.volume.xRange = 1; %[mm]
config.volume.yRange = 1; %[mm]
config.volume.nXPixels = 1000; %How many pixels in x direction
config.volume.nYPixels = 1000; %How many pixels in y direction
config.volume.nBScanAvg = 1;

%Depth Defenitions
%We assume stage starting position is at the top of the tissue.
%z defenitions below are compared to starting position
%+z is deeper
config.zToScan = ((-190:15:500)-5)*1e-3; %[mm]

%Tissue Defenitions
config.tissueRefractiveIndex = 1.4;

%Overview of the entire area
config.overview.isScanEnabled = false; %Do you want to scan overview volume? When running on Jenkins, will allways run overview 
config.overview.rangeAllX = 8;%[mm] Total tiles range
config.overview.rangeAllY = 7;%[mm] Total tiles range
config.overview.range = config.volume.xRange;%[mm] x=y range of each tile
config.overview.nPixels = max(config.volume.nXPixels/20,50); %same for x and y, number of pixels in each tile
config.overview.nZToScan = 3; %How many different depths to scan in overview to provide coverage

%Photobleaching defenitions
%Line placement (vertical - up/down, horizontal - left/right)
base = 100/1000; %base seperation [mm]
%LA,LB
%config.photobleach.vLinePositions = base*[-1 0 3]; %[mm] 
%config.photobleach.hLinePositions = base*[-1 0 2]; %[mm] 
%LC, LE
config.photobleach.vLinePositions = base*[-4  0 1 3]; %[mm] 
config.photobleach.hLinePositions = base*[-3 -2 1 3]; %[mm]
%LD
%config.photobleach.vLinePositions = base*[-3 -2 0 5 6]; %[mm] 
%config.photobleach.hLinePositions = base*[-4 -3 0 4 5]; %[mm] 
config.photobleach.exposure = 30/2; %[sec per line length (mm)]
config.photobleach.nPasses = 2;
config.photobleach.lineLength = 2; %[mm]
config.photobleach.isPhotobleachEnabled = true; %Would you like to photobleach? this flag disables all photobleaching
config.photobleach.isPhotobleachOverview = true; %Would you like to photobleach overview areas as well (extended photobleach)
config.photobleach.photobleachOverviewBufferZone = 0.170; %See extended lines design of #, this is to prevent multiple lines appearing in the same slice 
config.photobleach.z = -300*1e-3; %[mm] this parameter is ignored if running from jenkins - will assume provided by jenkins
    
%Probe defenitions
config.octProbePath = getProbeIniPath();

%Tickmarks (if required)
config.photobleach.isDrawTickmarks = false;
config.photobleach.tickmarksX0 = [0.3, -0.25];
config.photobleach.tickmarksY0 = [-0.25,0.25];

%Orientation dot
config.photobleach.isDrawTheDot = false;
config.theDotX = -config.photobleach.lineLength/2*0.8;
config.theDotY = +config.photobleach.lineLength/2*0.8;

%% Inputs from Jenkins
isExecutingOnJenkins = isRunningOnJenkins();
if (isRunningOnJenkins())
    outputFolder = outputFolder_; %Set by Jenkins
    config.photobleach.z = zToPhtobleach_; %Set by Jenkins
    config.photobleach.isDrawTickmarks = isDrawTickmarks_; %Set by Jenkins
    config.photobleach.isDrawTheDot = isDrawTickmarks_;
	config.overview.isScanEnabled = true;	
	
	if (exist('isDebugFastMode_','var') && isDebugFastMode_ == true) %Debug mode, make a faster scan
		disp('Entering debug mode!');
		config.volume.nXPixels = 100; 
		config.volume.nYPixels = 100; 
		config.overview.rangeAllX = 2;
        config.overview.rangeAllY = 1;
        config.photobleach.vLinePositions = base*[0]; %[mm] 
		config.photobleach.hLinePositions = base*[0]; %[mm] 
		config.photobleach.exposure = 5; %sec per mm
		config.zToScan = [config.zToScan(1:3) 0 config.zToScan(end)]; %Reduce number of Z scans
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
config.version = 2.1; %Version of this JSON file

%Scan one silce where we photobleaching
config.zToScan = unique([config.photobleach.z config.zToScan]);

%% Initialize Folders
%Make dirs for output and log
if ~exist(outputFolder,'dir')
	mkdir(outputFolder);
end
logFolder = [outputFolder '..\Log\01 OCT Scan and Pattern\'];
if ~exist(logFolder,'dir')
	mkdir(logFolder);
end

%% Compute Photobleaching Image
[ptStart_Scan, ptEnd_Scan, ptStart_Extended, ptEnd_Extended] = ScanAndPattern_GeneratePatternToPhotobleach(config);
saveas(gcf,[logFolder 'PhotobleachOverview.png']);

config.photobleach.ptStart_Scan = ptStart_Scan;
config.photobleach.ptEnd_Scan = ptEnd_Scan;
config.photobleach.ptStart_Extended = ptStart_Extended;
config.photobleach.ptEnd_Extended = ptEnd_Extended;
    
%% Actual Photobleach (first run)
if (config.photobleach.isPhotobleachEnabled)
%Safety warning
fprintf('%s Put on safety glasses. photobleaching in ...',datestr(datetime));
for i=5:-1:1
    fprintf(' %d',i);
    pause(1);
end
fprintf('\n');

%Photobleach without the part that moves
yOCTPhotobleachTile(config.photobleach.ptStart_Scan,config.photobleach.ptEnd_Scan,...
    'octProbePath',config.octProbePath,...
    'z',config.photobleach.z,'exposure',config.photobleach.exposure,...
    'nPasses',config.photobleach.nPasses);    
pause(0.5);

disp('Done');
end

%% Scans

%Volume
if (config.volume.isScanEnabled)
fprintf('%s Scanning Volume\n',datestr(datetime));
volumeOutputFolder = [outputFolder '\Volume\'];
scanParameters = yOCTScanTile (...
    volumeOutputFolder, ...
    'octProbePath', config.octProbePath, ...
    'tissueRefractiveIndex', config.tissueRefractiveIndex, ...
    'xOffset', 0, ...
    'yOffset', 0, ... 
    'xRange', config.volume.xRange, ...
    'yRange', config.volume.yRange, ...
    'nXPixels', config.volume.nXPixels, ...
    'nYPixels', config.volume.nYPixels, ...
    'nBScanAvg', config.volume.nBScanAvg, ...
    'zDepths',    config.zToScan, ... [mm]
    'v',true  ...
    );
for fn = fieldnames(scanParameters)'
    config.volume.(fn{1}) = scanParameters.(fn{1});
end
end

%Overview
if (config.overview.isScanEnabled)
	fprintf('%s Scanning Overview\n',datestr(datetime));
    
    %Overview center positons
    gridXc = (-config.overview.rangeAllX/2+config.overview.range/2):config.overview.range:(config.overview.rangeAllX/2-config.overview.range/2);
    gridYc = (-config.overview.rangeAllY/2+config.overview.range/2):config.overview.range:(config.overview.rangeAllY/2-config.overview.range/2);
    
    z = linspace( ...
        config.zToScan(2), ... Just above the tissue (index 1 is the photobleach position)
        config.zToScan(end)+0.5, ...Deepest depth of tissue scan, and add some after.
                                 ...This extra is for cases where tissue starts very deep so pathology will think it has a 'full face' when we couldn't see it in overview
        config.overview.nZToScan);
    
    overviewOutputFolder = [outputFolder '\Overview\'];
    scanParameters = yOCTScanTile (...
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
        'zDepths',    z, ... [mm]
        'xCenters', gridXc ,...
        'yCenters', gridYc ,...
        'v',true  ...
        );
    config.overview = rmfield(config.overview,{'nPixels','nZToScan','rangeAllX','rangeAllY'});
    for fn = fieldnames(scanParameters)'
        config.overview.(fn{1}) = scanParameters.(fn{1});
    end
end

%% Actual Photobleach (second run for overview photobleaching \ extended lines)

if config.photobleach.isPhotobleachOverview && config.photobleach.isPhotobleachEnabled
    %Safety warning
    fprintf('%s Photobleaching overview in ...',datestr(datetime));
    for i=5:-1:1
        fprintf(' %d',i);
        pause(1);
    end
    fprintf('\n');
    
    yOCTPhotobleachTile(config.photobleach.ptStart_Extended,config.photobleach.ptEnd_Extended,...
        'octProbePath',config.octProbePath,...
        'z',config.photobleach.z,'exposure',config.photobleach.exposure,...
        'nPasses',config.photobleach.nPasses); 
    pause(0.5);

    disp('Done');
end

%% Finalize
fprintf('%s Finalizing\n',datestr(datetime));

%Remove fields that are not in use again, their information is redundent
config = rmfield(config,{'tissueRefractiveIndex','zToScan'});
    
%Save scan configuration parameters
if exist([outputFolder 'ScanConfig.json'],'file')
	%Load Config first, dont override it
	cfg = awsReadJSON([outputFolder 'ScanConfig.json']);
    for fn = fieldnames(cfg)'
        config.(fn{1}) = cfg.(fn{1});
    end
end
disp('config');
config
disp('config.photobleach');
config.photobleach
disp('config.volume');
config.volume
disp('config.overview');
config.overview

%Save
awsWriteJSON(config, [outputFolder 'ScanConfig.json']);