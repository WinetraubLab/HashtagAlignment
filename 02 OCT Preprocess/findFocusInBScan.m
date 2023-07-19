%This script finds the position of the focus in the B scan image 
%(for stitching)

disp('Looking For Focus Position...');
%% Inputs

%OCT Data
OCTVolumesFolder = [s3SubjectPath('12','LE') 'OCTVolumes/'];
reconstructConfig = {'dispersionQuadraticTerm',6.539e07}; %Configuration for processing OCT Volume
%reconstructConfig = {'dispersionQuadraticTerm',9.56e7}; %Configuration for processing OCT Volume

isRunInAutomatedMode =  false;

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
end
LogFolder = [OCTVolumesFolder '..\Log\02 OCT Preprocess\'];

if (exist('isRunInAutomatedMode_','var'))
    isRunInAutomatedMode = isRunInAutomatedMode_;
end

%% Read Configuration file
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);

if (isfield(json,'focusPositionInImageZpix') && isRunInAutomatedMode)
    disp('Focus was found already, will not atempt finding focus again in Automatic Mode');
    return; %Don't try to focus again, only in manual mode
end

%% Decide if we use the volume or the overview to perform the estimation
if isfield(json.volume,'zDepths')
    disp('findFocusByUsing volume');
    OCTVolumesFolderVolume = [OCTVolumesFolder '/Volume/'];
elseif isfield(json.overview,'zDepths')
    disp('findFocusByUsing overview');
    OCTVolumesFolderVolume = [OCTVolumesFolder '/Overview/'];
end

%% Find the focus
focusPositionInImageZpix = yOCTFindFocusTilledScan(...
    OCTVolumesFolderVolume,'reconstructConfig',reconstructConfig,...
    'manualRefinment',~isRunInAutomatedMode,'verbose',true);

%% Output & Save
%Update JSON
json.focusPositionInImageZpix = focusPositionInImageZpix;
json.VolumeOCTDimensions = dim;
awsWriteJSON(json,[OCTVolumesFolder 'ScanConfig.json']); %Can save locally or to AWS

%Output Tiff
ax = gca;
saveas(ax,'FindFocusInBScan.png');
if (awsIsAWSPath(OCTVolumesFolder))
    %Upload to AWS
    awsCopyFileFolder('FindFocusInBScan.png',[LogFolder '/FindFocusInBScan.png']);
else
    if ~exist(LogFolder,'dir')
        mkdir(LogFolder)
    end
    copyfile('FindFocusInBScan.png',[LogFolder '\FindFocusInBScan.png']);
end   