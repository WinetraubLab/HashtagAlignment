%This script finds the position of the focus in the B scan image 
%(for stitching)

disp('Looking For Focus Position...');
%% Inputs

%OCT Data
OCTVolumesFolder = [s3SubjectPath('12','LHC') 'OCTVolumes/'];
reconstructConfig = {'dispersionQuadraticTerm',6.539e07}; %Configuration for processing OCT Volume

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

if isfield(json.volume,'tissueRefractiveIndex')
    n = json.volume.tissueRefractiveIndex; 
elseif isfield(json.overview,'tissueRefractiveIndex')
    n = json.overview.tissueRefractiveIndex; 
else
    warning('Can''t figure out what is index of refraction, assuming default value');
    n = 1.33;
end

%% Find a scan that was done when tissue was at focus (z=0)
%Decide wheter to use scan or overview for findig focus
if isfield(json.volume,'zDepths')
    findFocusByUsing = 'volume';
    zDepths = json.volume.gridZcc; 
    
    %Find the frame to be used 
    frameI = find(abs(zDepths) == min(abs(zDepths)),1,'first'); %Find the one closest to 0
    
    %Define a path by frame
    OCTVolumesFolderVolume = [OCTVolumesFolder '/Volume/'];
    fp = sprintf('%sData%02d/',OCTVolumesFolderVolume,frameI);
    
    %Define range
    xRange = json.volume.xRange;
    yRange = json.volume.yRange;

elseif isfield(json.overview,'zDepths')
    findFocusByUsing = 'overview';
    zDepths = json.overview.gridZcc;
    
    %Find the frame to be used 
    frameI = find(abs(zDepths) == min(abs(zDepths)),1,'first'); %Find the one closest to 0
    
    %Define a path by frame
    OCTVolumesFolderVolume = [OCTVolumesFolder '/Overview/'];
    fp = sprintf('%sData%02d/',OCTVolumesFolderVolume,frameI);
    
    %Define range
    xRange = json.overview.range;
    yRange = json.overview.range;
end

%% Find Focus Positions for 10x and 40x
if strcmp(octProbeLens_, '10x')
    zFocusPix = yOCTFindFocus(fp, {'tissueRefractiveIndex', n});
elseif strcmp(octProbeLens_, '40x')
    zFocusPix = yOCTFindFocus(OCTVolumesFolder, {'zDepthStitchingMode', true, 'tissueRefractiveIndex', n});
end

%% Output & Save

%Update JSON
json.focusPositionInImageZpix = zFocusPix;
json.VolumeOCTDimensions = dim;
awsWriteJSON(json,[OCTVolumesFolder 'ScanConfig.json']); %Can save locally or to AWS
