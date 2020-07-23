%This script stitches images aquired at different z depths 2gezer
%Mac Only:
setenv('PATH', [getenv('PATH') ':/usr/local/bin']);
%OCT Data
OCTVolumesFolder = 's3://delazerdamatlab/Users/BrainProject/7-2-2020Ganymede20x/';
dispersionQuadraticTerm = [8e07]; %Use default that is specified in ini probe file

focusSigma = 20; %When stitching along Z axis (multiple focus points), what is the size of each focus in z [pixel]
outputFileFormat = 'tif'; %Can be 'tif' or 'mat' for debug

isRunOnJenkins = false;

%% Bands
start1 = 796.23000000000013;
end1 = 903.0565;
start2 = 903.1633;
end2 =1.0100e+03;
%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
    isRunOnJenkins = true;
end

%% Directories 
OCTVolumesFolder = awsModifyPathForCompetability([OCTVolumesFolder '\']);
SubjectFolder = awsModifyPathForCompetability([OCTVolumesFolder '\']);

logFolder = awsModifyPathForCompetability([SubjectFolder '\Log\VolumeDebug\']);
outputFolder1 = awsModifyPathForCompetability([OCTVolumesFolder '/VolumeScanAbsBand1/']);
outputFolder2 = awsModifyPathForCompetability([OCTVolumesFolder '/VolumeScanAbsBand2/']);

%% Process scan
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);

if ~isfield(json,'focusPositionInImageZpix')
    error('Please run findFocusInBScan first');
end

if isRunOnJenkins
    setupParpolOCTPreprocess();
end
tic;
fprintf('Processing Band 1\n');
yOCTProcessTiledScan(...
        [OCTVolumesFolder 'Volume/'], ... Input
        {outputFolder1 [outputFolder(1:(end-1)) '_All_Band1.tif']},...
        'focusPositionInImageZpix',json.focusPositionInImageZpix,... No Z scan filtering
		'focusSigma',focusSigma,...
        'dispersionQuadraticTerm',dispersionQuadraticTerm,...
		'yPlanesOutputFolder',[logFolder 'Band1\'],...
        'howManyYPlanes',3,... Save some raw data ys if there are multiple depths
        'band',[start1 end1],...
        'v',true);
fprintf('Band1 run time: %d min and %.1f seconds\n', fix(toc/60),rem(toc,60));
fprintf('Processing Band 2\n');
yOCTProcessTiledScan(...
        [OCTVolumesFolder 'Volume/'], ... Input
        {outputFolder2 [outputFolder(1:(end-1)) '_All_Band2.tif']},...
        'focusPositionInImageZpix',json.focusPositionInImageZpix,... No Z scan filtering
		'focusSigma',focusSigma,...
        'dispersionQuadraticTerm',dispersionQuadraticTerm,...
		'yPlanesOutputFolder',[logFolder 'Band2\'],...
        'howManyYPlanes',3,... Save some raw data ys if there are multiple depths
        'band',[start2 end2],...
        'v',true);
fprintf('Band2 run time: %d min and %.1f seconds\n', fix(toc/60),rem(toc,60));