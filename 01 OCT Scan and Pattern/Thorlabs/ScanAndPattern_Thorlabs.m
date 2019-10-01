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
config.volume.rangeX = 1; %[mm]
config.volume.rangeY = 1; %[mm]
config.volume.nPixelsX = 1000; %How many pixels in x direction
config.volume.nPixelsY = 1000; %How many pixels in y direction
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
config.overview.rangeAllX = 6;%[mm] Total tiles range
config.overview.rangeAllY = 5;%[mm] Total tiles range
config.overview.range = config.volume.rangeX;%[mm] x=y range of each tile
config.overview.nPixels = max(config.volume.nPixelsX/20,50); %same for x and y, number of pixels in each tile
config.overview.nZToScan = 2; %How many different depths to scan in overview to provide coverage

%Photobleaching defenitions
%Line placement (vertical - up/down, horizontal - left/right)
base = 100/1000; %base seperation [mm]
%config.photobleach.vLinePositions = base*[-1 0 3]; %[mm] 
%config.photobleach.hLinePositions = base*[-1 0 2]; %[mm] 
config.photobleach.vLinePositions = base*[-4  0 1 3]; %[mm] 
config.photobleach.hLinePositions = base*[-3 -2 1 3]; %[mm] 
config.photobleach.exposure = 30/2; %[sec per line length (mm)]
config.photobleach.nPasses = 2;
config.photobleach.lineLength = 2; %[mm]
config.photobleach.isPhotobleachEnabled = true; %Would you like to photobleach? this flag disables all photobleaching
config.photobleach.isPhotobleachOverview = true; %Would you like to photobleach overview areas as well (extended photobleach)
config.photobleach.z = -300*1e-3; %[mm] this parameter is ignored if running from jenkins - will assume provided by jenkins
    
%Probe defenitions
config.octProbePath = [currentFileFolder 'Probe - Olympus 10x.ini'];
config.octProbeFOV  = [2 2]; %mm
%Define scale and offset for fast & slow axis calibration
config.offsetX = 0/1000; %[mm]
config.offsetY = 0; %[mm]
config.scaleX =  0.99421;
config.scaleY =  1;

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
		config.volume.nPixelsX = 100; 
		config.volume.nPixelsY = 100; 
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
config.version = 2; %Version of this JSON file

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
ptStart = [];
ptEnd = [];

%H & V Lines
ptStart = [];
ptEnd = [];

%H & V Lines
if (~config.photobleach.isPhotobleachOverview)
    lx = config.photobleach.lineLength;
    ly = config.photobleach.lineLength;
else
    lx = config.overview.rangeAllX;
    ly = config.overview.rangeAllY;
end
for i=1:length(config.photobleach.vLinePositions)
    ptStart(:,end+1) = [config.photobleach.vLinePositions(i);-ly/2]; %Start
    ptEnd(:,end+1)   = [config.photobleach.vLinePositions(i);+ly/2]; %Ebd
end
for i=1:length(config.photobleach.hLinePositions)
    ptStart(:,end+1) = [-lx/2; config.photobleach.hLinePositions(i)]; %Start
    ptEnd(:,end+1)   = [+lx/2; config.photobleach.hLinePositions(i)]; %Ebd
end

%Tick marks 
if (config.photobleach.isDrawTickmarks)

    %Make sure tick marks don't collide with regular lines
    clrnce = 0.1;
    isCleared = @(x,y)( ...
        ( ...
            x < (min (config.photobleach.vLinePositions)-clrnce) | ...
            x > (max (config.photobleach.vLinePositions)+clrnce)   ...
        ) & ( ... 
            y < (min (config.photobleach.hLinePositions)-clrnce) | ...
            y > (max (config.photobleach.hLinePositions)+clrnce)   ...
        ) );
    for i=1:length(config.photobleach.tickmarksX0)
        c = [config.photobleach.tickmarksX0(i)/2; config.photobleach.tickmarksY0(i)/2];
        v = [config.photobleach.tickmarksX0(i); -config.photobleach.tickmarksY0(i)]; v = v/norm(v);

        [pts,pte] = yOCTApplyEnableZone(...
            c-v*config.photobleach.lineLength, ...
            c+v*config.photobleach.lineLength, ...
            isCleared, 10e-3);

        ptStart = [ptStart pts];
        ptEnd = [ptEnd pte];
    end
end

if config.photobleach.isDrawTheDot
    ptStart = [ptStart ([ config.theDotX+0.1*[-1 0] ; config.theDotY+0.1*[0 -1]])];
    ptEnd   = [ptEnd   ([ config.theDotX+0.1*[+1 0] ; config.theDotY+0.1*[0 +1]])];
end

if ~config.photobleach.isPhotobleachOverview
    %Trim everything to one FOV if it doesn't fit
    [ptStart,ptEnd] = yOCTApplyEnableZone(ptStart, ptEnd, ...
            @(x,y)(abs(x)<config.octProbeFOV(1)/2 & abs(y)<config.octProbeFOV(2)/2) , 10e-3);
end

if (~config.photobleach.isPhotobleachEnabled)
    ptStart = [];
    ptEnd = [];
end

%Plot
figure(2); subplot(1,1,1);
for i=1:size(ptStart,2)
    plot([ptStart(1,i) ptEnd(1,i)], [ptStart(2,i) ptEnd(2,i)]);
    if (i==1)
        hold on;
    end
end
rectangle('Position',[-config.volume.rangeX/2 -config.volume.rangeY/2 config.volume.rangeY config.volume.rangeY]);
hold off;
axis equal;
axis ij;
grid on;
xlabel('x[mm]');
ylabel('y[mm]');
saveas(gcf,[logFolder 'PhotobleachOverview.png']);

config.photobleach.ptStart = ptStart;
config.photobleach.ptEnd = ptEnd;
    
%% Actual Photobleach (first run)
if (config.photobleach.isPhotobleachEnabled)
%Safety warning
fprintf('%s Put on safety glasses. photobleaching in ...',datestr(datetime));
for i=5:-1:1
    fprintf(' %d',i);
    pause(1);
end
fprintf('\n');

yOCTPhotobleachTile(config.photobleach.ptStart,config.photobleach.ptEnd,...
    'octProbePath',config.octProbePath,'FOV',config.octProbeFOV,...
    'z',config.photobleach.z,'exposure',config.photobleach.exposure,...
    'nPasses',config.photobleach.nPasses,...
    'enableZone',@(x,y)(abs(x)<config.octProbeFOV(1)/2 & abs(y)<config.octProbeFOV(2)/2));
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
    'xOffset', config.offsetX, ...
    'yOffset', config.offsetY, ... 
    'xRange', config.volume.rangeX * config.scaleX, ...
    'yRange', config.volume.rangeY * config.scaleY, ...
    'nXPixels', config.volume.nPixelsX, ...
    'nYPixels', config.volume.nPixelsY, ...
    'nBScanAvg', config.volume.nBScanAvg, ...
    'zDepts',    config.zToScan, ... [mm]
    'v',true  ...
    );
config.volume = rmfield(config.volume,{'nPixelsX','nPixelsY','nBScanAvg'});
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
    
    z = config.zToScan(2:end); %Ignore photobleaching depth at z(1)
    %z(z<0) = []; %Overview should be scanned in tissue 
    z = z(round(linspace(1,length(z),min(config.overview.nZToScan,length(z)))));
    
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
        'zDepts',    z, ... [mm]
        'xCenters', gridXc ,...
        'yCenters', gridYc ,...
        'v',true  ...
        );
    config.overview = rmfield(config.overview,{'range','nPixels','nZToScan','rangeAllX','rangeAllY'});
    for fn = fieldnames(scanParameters)'
        config.overview.(fn{1}) = scanParameters.(fn{1});
    end
end

%% Actual Photobleach (second run for overview photobleaching)

if config.photobleach.isPhotobleachOverview && config.photobleach.isPhotobleachEnabled
    %Safety warning
    fprintf('%s Photobleaching overview in ...',datestr(datetime));
    for i=5:-1:1
        fprintf(' %d',i);
        pause(1);
    end
    fprintf('\n');

    yOCTPhotobleachTile(config.photobleach.ptStart,config.photobleach.ptEnd,...
        'octProbePath',config.octProbePath,'FOV',config.octProbeFOV,...
        'z',config.photobleach.z,'exposure',config.photobleach.exposure,...
        'nPasses',config.photobleach.nPasses,...
        'enableZone',@(x,y)(~(abs(x)<config.octProbeFOV(1)/2 & abs(y)<config.octProbeFOV(2)/2))); %Photobleach the outside
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