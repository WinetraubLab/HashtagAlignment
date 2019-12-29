%This script stitches images aquired at different z depths 2gezer

%OCT Data
OCTVolumesFolder = [s3SubjectPath('01') 'OCTVolumes/'];
dispersionParameterA = []; %Use default that is specified in ini probe file

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
        {outputFolder [outputFolder(1:(end-1) '_All.tif']},...
        'focusPositionInImageZpix',focusPositionInImageZpix,... No Z scan filtering
		'focusSigma',focusSigma,...
        'dispersionParameterA',dispersionParameterA,...
		'yPlanesOutputFolder',[logFolder 'Debug\'],...
        'howManyYPlanes',3,... Save some raw data ys if there are multiple depths
        'v',true);