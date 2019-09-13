%This script stitches images aquired at different z depths 2gezer

%OCT Data
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-00D/OCTVolumes/';
dispersionParameterA = 6.539e07;

focusSigma = 20; %When stitching along Z axis (multiple focus points), what is the size of each focus in z [pixel]
outputFileFormat = 'tif'; %Can be 'tif' or 'mat' for debug

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
end

%% Directories 
OCTVolumesFolder = awsModifyPathForCompetability([OCTVolumesFolder '\']);
SubjectFolder = awsModifyPathForCompetability([OCTVolumesFolder '..\']);

logFolder = awsModifyPathForCompetability([SubjectFolder '\Log\02 OCT Preprocess\VolumeDebug\']);
outputFolder = awsModifyPathForCompetability([OCTVolumesFolder '/VolumeScanAbs/']);

%% Process scan
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);

if ~isfield(json,'focusPositionInImageZpix')
    error('Please run findFocusInBScan first');
end

setupParpolOCTPreprocess();
yOCTProcessTiledScan(...
    [OCTVolumesFolder 'Volume\'], ... Input
    outputFolder,...
    'debugFolder',logFolder,...
    'saveYs',3,... 
    'focusPositionInImageZpix',json.focusPositionInImageZpix,... No Z scan filtering
    'dispersionParameterA',dispersionParameterA,...
    'outputFileFormat',outputFileFormat,...
    'focusSigma',focusSigma,...
    'v',true);
