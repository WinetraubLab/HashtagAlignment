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

% Lens
config.octProbeLens = '40x'; % Which lens we use for this experiment
if (isRunningOnJenkins() && exist('octProbeLens_','var'))
    config.octProbeLens = octProbeLens_;
end

% Lens based configuration
switch(config.octProbeLens)
    case '10x'
        volumeSize = 1; %mm
        overviewSingleTileVolumeSize = 1; %mm
        exposure = 15; % sec per mm line
        photobleachUnderInterface_mm = +50e-3; % We don't want to photobleach exactly at the gel-air interface. How much below it? (mm)
        scanZJump_um = 15;% Scan every x um in z
        overview_nZToScanDefault = 3; % How many depth points to scan overview in
		nPixels = 1000;
        
        % Photobleaching
        vLinePositions = [-4  0 1 3]; %Unitless, vLine positions as multiplication of base
        hLinePositions = [-3 -2 1 3]; %Unitless, hLine positions as multiplication of base
		base = 100e-3; %base seperation [mm], we don't want to go under 0.1mm because lines become overlap.
        numberOfLinesInOverview=3;
        photobleachOverviewBufferZone=0.170; %[mm]
        
        tissueRefractiveIndex = 1.4; % Silicon Oil
        maxLensFOV = []; % Use lens default
    case '40x'
        volumeSize = 0.5; %mm
		nPixels = 500;
        overviewSingleTileVolumeSize = 0.8; %mm
        exposure = 15; % sec per mm line
        photobleachUnderInterface_mm = +75e-3; %+50e-3 + [0 75e-3 150e-3]; % [mm] We don't want to photobleach exactly at the gel-air interface. How much below it? (mm). 40x we photobleach in a few spots
        scanZJump_um = 5;% Scan every x um i z
        overview_nZToScanDefault = 2; % How many depth points to scan overview in. At 40x we have so many overview tiles, its worth scanning less
        
        % Photobleaching
		base = 75e-3; %base seperation [mm]
        vLinePositions = [-2 -1 2]; %Unitless, vLine positions as multiplication of base
        hLinePositions = [-1  0 2]-0.5; %Unitless, hLine positions as multiplication of base
        
		base = 100e-3; %base seperation [mm], we don't want to go under 0.1mm because lines become overlap.
        vLinePositions = [-4  0 1 3]+7; %Unitless, vLine positions as multiplication of base
        hLinePositions = [-3 -2 1 3]-0.4/base; %Unitless, hLine positions as multiplication of base
		
        photobleachOverviewBufferZone = 0; %
        numberOfLinesInOverview = 4;
        
        tissueRefractiveIndex = 1.33; % Water
        
        maxLensFOV = 0.3; %mm, smaller than FOV of the lens to have better lines
end

% OCT scan defenitions (scan is centered along (0,0)
config.volume.isScanEnabled = true; %Enable/Disable regular scan
config.volume.xRange = volumeSize; %[mm]
config.volume.yRange = volumeSize; %[mm]
config.volume.nXPixels = nPixels; %How many pixels in x direction
config.volume.nYPixels = nPixels; %How many pixels in y direction
config.volume.nBScanAvg = 1;

% Depth Defenitions
% We assume stage starting position is at the top of the tissue.
% z defenitions below are compared to starting position
% +z is deeper
config.zToScan = ((-190:scanZJump_um:500)-5)*1e-3; %[mm]	
config.isZScanStartFromTop = false; % Would you like to start scanning from the top of the sample (true) or bottom (false)

% Tissue Defenitions
config.tissueRefractiveIndex = tissueRefractiveIndex;
config.gelIterfacePosionWithRespectToTissueTop_mm = -300e-3; %[mm]. Z position of the gel-air interface compared to gel-tissue interface. Negative Z means above.

% Overview of the entire area
config.overview.isScanEnabled = false; %Do you want to scan overview volume? When running on Jenkins, will allways run overview 
config.overview.rangeAllX = 8;%[mm] Total tiles range
config.overview.rangeAllY = 7;%[mm] Total tiles range
config.overview.range = overviewSingleTileVolumeSize;%[mm] x=y range of each tile
config.overview.nPixels = max(config.volume.nXPixels/20,50); %same for x and y, number of pixels in each tile
config.overview.nZToScan = overview_nZToScanDefault; %How many different depths to scan in overview to provide coverage

% Photobleaching defenitions
% Line placement (vertical - up/down, horizontal - left/right)
config.photobleach.vLinePositions = base*vLinePositions; %[mm] 
config.photobleach.hLinePositions = base*hLinePositions; %[mm]
config.photobleach.exposure = exposure; %[sec per line length (mm)]
config.photobleach.nPasses = 2;
config.photobleach.lineLength = volumeSize*2; %[mm]
config.photobleach.isPhotobleachEnabled = true; %Would you like to photobleach? this flag disables all photobleaching
config.photobleach.isPhotobleachOverview = true; %Would you like to photobleach overview areas as well (extended photobleach)
config.photobleach.photobleachOverviewBufferZone = photobleachOverviewBufferZone; %[mm] See extended lines design of #, this is to prevent multiple lines appearing in the same slice 
config.photobleach.numberOfLinesInOverview = numberOfLinesInOverview; % Number of v&h lines in overview (outside of main OCT scan area)
config.photobleach.maxLensFOV = maxLensFOV; % mm
   
% Probe defenitions
config.octProbePath = yOCTGetProbeIniPath(config.octProbeLens);
config.oct2stageXYAngleDeg = +1.59; % Current calibration angle between OCT and Stage 
% See findMotorAngleCalibration if you need to recalibrate (e.g. when OCT head was moved)

% Tickmarks (if required)
config.photobleach.isDrawTickmarks = false;
config.photobleach.tickmarksX0 = [0.3, -0.25];
config.photobleach.tickmarksY0 = [-0.25,0.25];

% Orientation dot
config.photobleach.isDrawTheDot = false;
config.theDotX = +config.photobleach.lineLength/2*0.8;
config.theDotY = -config.photobleach.lineLength/2*0.8;

%% Inputs from Jenkins
isExecutingOnJenkins = isRunningOnJenkins();
if (isRunningOnJenkins())
    outputFolder = outputFolder_; %Set by Jenkins
    config.gelIterfacePosionWithRespectToTissueTop_mm = zGelTop_mm_; %Set by Jenkins
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
	
	% Setup for faster execution
	if exist('zToScan_','var')
		% User defined zToScan.
		% If you would like fast zTOScan_ but one that coveres all the essentials use:
		% zToScan_ = (([-190,5,500])-5)*1e-3;
		config.zToScan = zToScan_;
	end	
	if exist('overview_rangeAllX_','var')
		% For faster execution: overview_rangeAllX_ = 5
		config.overview.rangeAllX = overview_rangeAllX_;
	end
	if exist('overview_rangeAllY_','var')
		% For faster execution: overview_rangeAllY_ = 4
		config.overview.rangeAllY = overview_rangeAllY_;
	end
	if exist('overview_nZToScan_','var')
		% For faster execution: overview_nZToScan_ = 2
		config.overview.nZToScan = overview_nZToScan_;
	end
end

if exist('gitBranch_','var')
    config.gitBranchUsedToScan = gitBranch_; %Save which git branch was used to scan
else
    config.gitBranchUsedToScan = 'unknown';
end

% Photobleach x microns under gel top
config.photobleach.z = ...
    config.gelIterfacePosionWithRespectToTissueTop_mm ...
    + photobleachUnderInterface_mm; %[mm] where to photobleach. We usually want to photobleach a little under the top of the gel

%% Add preprogramed config parameter

% Input check
if ~any(config.zToScan == 0)
	error('zToScan does not contain focus (z=0) that will cause problems down the road, please adjust');
end

% Scan one silce where we photobleaching
config.zToScan_TopOfGelZ = config.gelIterfacePosionWithRespectToTissueTop_mm;
config.zToScan_TopTissueZ = config.zToScan(1);
config.zToScan = unique([config.zToScan_TopOfGelZ config.zToScan]);

% Flip zToScan if user selected to start from the bottom
if (~config.isZScanStartFromTop)
    config.zToScan = fliplr(config.zToScan);
end

% Housekeeping parameters
config.whenWasItScanned = datestr(now());
config.version = 2.2; %Version of this JSON file

%% Initialize Folders
% Make dirs for output and log
if ~exist(outputFolder,'dir')
	mkdir(outputFolder);
    addpath(genpath(outputFolder));
end
logFolder = awsModifyPathForCompetability([outputFolder '..\Log\01 OCT Scan and Pattern\']);
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

% Image with photobleach windows
yOCTPhotobleachTile(config.photobleach.ptStart_Extended,config.photobleach.ptEnd_Extended,...
    'octProbePath',config.octProbePath,...
    'z',config.photobleach.z,'exposure',config.photobleach.exposure,...
    'nPasses',config.photobleach.nPasses,...
	'oct2stageXYAngleDeg', config.oct2stageXYAngleDeg,...
    'maxLensFOV',config.photobleach.maxLensFOV,...
    'utilizeAllFOV',false,...
    'plotPattern',true,'skipHardware',true);

return;

%% Actual Photobleach (first run)
if (config.photobleach.isPhotobleachEnabled)
% Safety warning
fprintf('%s Put on safety glasses. photobleaching in ...',datestr(datetime));
for i=5:-1:1
    fprintf(' %d',i);
    pause(1);
end
fprintf('\n');

% Photobleach without the part that moves
yOCTPhotobleachTile(config.photobleach.ptStart_Scan,config.photobleach.ptEnd_Scan,...
    'octProbePath',config.octProbePath,...
    'z',config.photobleach.z,'exposure',config.photobleach.exposure,...
    'nPasses',config.photobleach.nPasses,...
	'oct2stageXYAngleDeg', config.oct2stageXYAngleDeg,...
    'maxLensFOV',config.photobleach.maxLensFOV,...
    'plotPattern',true);    
pause(0.5);

disp('Done');
end

%% Scans

% Volume
if (config.volume.isScanEnabled)
fprintf('%s Scanning Volume\n',datestr(datetime));
volumeOutputFolder = [outputFolder '\Volume\'];
scanParameters = yOCTScanTile (...
    volumeOutputFolder, ...
    'octProbePath', config.octProbePath, ...
    'tissueRefractiveIndex', config.tissueRefractiveIndex, ...
    'xOffset',   0, ...
    'yOffset',   0, ... 
    'xRange',    config.volume.xRange, ...
    'yRange',    config.volume.yRange, ...
    'nXPixels',  config.volume.nXPixels, ...
    'nYPixels',  config.volume.nYPixels, ...
    'nBScanAvg', config.volume.nBScanAvg, ...
    'zDepths',   config.zToScan, ... [mm]
	'oct2stageXYAngleDeg', config.oct2stageXYAngleDeg, ...
    'v',true  ...
    );
for fn = fieldnames(scanParameters)'
    config.volume.(fn{1}) = scanParameters.(fn{1});
end
end

% Overview
if (config.overview.isScanEnabled)
	fprintf('%s Scanning Overview\n',datestr(datetime));
    
    % Overview center positons
    gridXc = (-config.overview.rangeAllX/2+config.overview.range/2):config.overview.range:(config.overview.rangeAllX/2-config.overview.range/2);
    gridYc = (-config.overview.rangeAllY/2+config.overview.range/2):config.overview.range:(config.overview.rangeAllY/2-config.overview.range/2);
    
    % What depths to scan overview
    z = linspace( ...
        config.zToScan_TopTissueZ, ... Just above the tissue
        max(config.zToScan)+0.2, ...Deepest depth of tissue scan, and add some after.
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
		'oct2stageXYAngleDeg', config.oct2stageXYAngleDeg, ...
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
        'z',config.photobleach.z, ... For exended lines just photobleach the first depth (no need to do deeper)
        'exposure',config.photobleach.exposure,...
        'nPasses',config.photobleach.nPasses,...
		'oct2stageXYAngleDeg', config.oct2stageXYAngleDeg,...
        'maxLensFOV',config.photobleach.maxLensFOV,...
        'plotPattern',true); 
    pause(0.5);

    disp('Done');
end

%% Finalize
fprintf('%s Finalizing\n',datestr(datetime));

% Remove fields that are not in use again, their information is redundent
config = rmfield(config,{'tissueRefractiveIndex','zToScan'});
    
% Save scan configuration parameters
if exist([outputFolder 'ScanConfig.json'],'file')
	% Load Config first, dont override it
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

% Save config
awsWriteJSON(config, [outputFolder 'ScanConfig.json']);