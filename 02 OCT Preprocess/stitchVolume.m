%This script stitches images aquired at different z depths 2gezer

%OCT Data
OCTVolumesFolder = [s3SubjectPath('36','LK') 'OCTVolumes/'];
dispersionQuadraticTerm = []; %Use default that is specified in ini probe file

% Smoothing parameter
sigma_um = 1.5; %microns

isRunOnJenkins = false;

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
    isRunOnJenkins = true;
end

%% Directories 
OCTVolumesFolder = awsModifyPathForCompetability([OCTVolumesFolder '\']);
SubjectFolder = awsModifyPathForCompetability([OCTVolumesFolder '..\']);

logFolder = awsModifyPathForCompetability([SubjectFolder '\Log\02 OCT Preprocess\VolumeDebug\']);
outputFolder = awsModifyPathForCompetability([OCTVolumesFolder '/VolumeScanAbs/']);
outputTiffFile = [outputFolder(1:(end-1)) '_All.tif'];

%% Lens Based Settings
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);
switch(json.octProbeLens)
    case '10x'
        focusSigma = 20; %When stitching along Z axis (multiple focus points), what is the size of each focus in z [pixel]
    case '40x'
        focusSigma = 1; %When stitching along Z axis (multiple focus points), what is the size of each focus in z [pixel]
end

%% Process scan
if ~isfield(json,'focusPositionInImageZpix')
    error('Please run findFocusInBScan first');
end

if isRunOnJenkins
    setupParpolOCTPreprocess();
end
yOCTProcessTiledScan(...
        [OCTVolumesFolder 'Volume\'], ... Input
        {outputTiffFile},... Save only Tiff file as folder will be generated after smoothing
        'focusPositionInImageZpix',json.focusPositionInImageZpix,... No Z scan filtering
		'focusSigma',focusSigma,...
        'dispersionQuadraticTerm',dispersionQuadraticTerm,...
		'yPlanesOutputFolder',[logFolder 'Debug\'],...
        'howManyYPlanes',3,... Save some raw data ys if there are multiple depths
        'interpMethod','sinc5', ...
        'v',true);
    
%% Apply gaussian filtering % threshold

% Load the data we just processed
[data, metadata, c] = yOCTFromTif(outputTiffFile);
metadata_um = yOCTChangeDimensionsStructureUnits(metadata,'um');

% Compute Gaussian filter (XY only)
dx_um = diff(metadata_um.x.values(1:2)); % Pixel size in microns
grid = -(4*sigma_um):(4*sigma_um);
[z,x,y]=ndgrid(0,grid,grid);
filt = exp(-(x.^2+y.^2+(z*2).^2)/(2*sigma_um.^2));
filt = filt / sum(filt(:)); % Normalization

% Apply Gaussian filtering
dataFilt = mag2db(convn(db2mag(data),filt,'same'));

% Find threshold
average_signal = mean(dataFilt,[2 3]); % Create an average singal
p = ceil(rand(1,100000)*numel(dataFilt)); % Speed up the job by using a subset of the data
c_max = prctile(dataFilt(p),99.99); 
c_min = min(average_signal);

% Present to user
imagesc(...
    metadata.x.values,... 
    metadata.z.values,...
    squeeze(dataFilt(:,:,100)));colormap('gray');
caxis([c_min c_max]);
axis equal;
xlabel('mm');

% Save new version (override the original)
yOCT2Tif(dataFilt,{outputFolder outputTiffFile}, 'metadata',metadata,'clim',[c_min c_max]);