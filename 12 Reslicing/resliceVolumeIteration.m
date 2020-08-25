% This script reslices an OCT volume for a specific iteration, assumes the
% following was already run:
%   1) 01 OCT Preprocess - pre-process volume (optional, this script can
%       reprocess)
%   2) 11 Align OCT to Flourecence Imaging - alignment was calculated

appendToDimensions.note = [...
    'Y direction at the resliced volume is not along the cutting direction!\n' ...
    'Its just prepandicular to u and v which may be anti-parallel to histology cutting direction.\n'];

isReProcessOCT = false;
whichIterationsToReslice = 2; % Can be a number or array of numbers if more than one iteration is required.
runningOnJenkins = false;

% When reslicing take some buffer (microns) before the first slice and
% after the last one
bufferSize_um = 220; % take some buffer on both ends.


subjectFolder = s3SubjectPath('01');

if exist('subjectFolder_','var')
    subjectFolder = subjectFolder_; %Jenkins
    isReProcessOCT = isReProcessOCT_;
    whichIterationsToReslice = whichIterationsToReslice_;
    runningOnJenkins = true;
end

% If not empty, will write the overview files to Log Folder
logFolder = awsModifyPathForCompetability([subjectFolder '/Log/12 Reslicing/']);
OCTVolumesFolder = awsModifyPathForCompetability([subjectFolder '/OCTVolumes/']);

%logFolder = [];

%% Load JSONs with information
subjectFolder = awsModifyPathForCompetability(subjectFolder);
[~,subjectName] = fileparts([subjectFolder(1:end-1) '.a']);

% Stack Config
scJsonFilePath = awsModifyPathForCompetability([subjectFolder '/Slides/StackConfig.json']);
scJson = awsReadJSON(scJsonFilePath);

istr = sprintf('%d,',whichIterationsToReslice);
fprintf('%s Re-slicing %s, iteration(s): %s.\n',datestr(now),subjectName,istr(1:(end-1)));

%% Pre-process volume (if needed)
if isReProcessOCT
    fprintf('%s Re-pre-processing first.\n',datestr(now));
    preprocessVolume(OCTVolumesFolder);
end

tifVolumePath = [OCTVolumesFolder 'VolumeScanAbs/'];
%% Copy files locally if processing locally
poolobj = gcp('nocreate');
isProcessLocallyBeforeUploading = false;
if awsIsAWSPath(OCTVolumesFolder) && ...
    (...
        isempty(poolobj) && strcmp(parallel.defaultClusterProfile,'local') || ... No pool opened, so determine if will run locally using default cluster
        strcmp(poolobj.Cluster.Profile,'local') ... Cluster, is open, figure out if its local cluster
    ) && runningOnJenkins
    isProcessLocallyBeforeUploading = true;
    
    fprintf('%s Copying data to local folder for faster processing time...\n',datestr(now));

    baseTmpFolder = [tempname '\'];
    tifVolumePath = [baseTmpFolder 'Volume.tif']; % Single big tif file is better for processing locally
    awsCopyFileFolder(...
        [OCTVolumesFolder 'VolumeScanAbs_All.tif'], tifVolumePath);
   
    fprintf('%s Done.\n',datestr(datetime));
    
    tifResliceVolumePath = [baseTmpFolder 'ReslicedVolume\'];
end        

% Load OCT Dimensions
[~, dimensions] = yOCTFromTif(tifVolumePath,'isLoadMetadataOnly',true);

%% Reslice 
for sI = 1:length(whichIterationsToReslice)
    fprintf('%s Reslicing Iteration %d ...\n',datestr(now), whichIterationsToReslice(sI));
    % Check that data exists
    if (~isfield(scJson,'stackAlignment') || length(scJson.stackAlignment) < whichIterationsToReslice(sI))
        warning('Cannot process iteration %d, it does not exist in StackConfig.json. Skipping',whichIterationsToReslice(sI));
        continue;
    end
    stackAlignment = scJson.stackAlignment(whichIterationsToReslice(sI));
    
    % Figure out how to slice on y' direction (new y direction)
    n = stackAlignment.planeNormal; % Normal to plane, make sure not to flip it otherwise image will be fliped!
    d_um = stackAlignment.planeDistanceFromOCTOrigin_um;
    
    % Dimensions of the original volume (mm)
    xRange = max(dimensions.x.values) - min(dimensions.x.values);
    yRange = max(dimensions.y.values) - min(dimensions.y.values);
    xSpan = sqrt(xRange^2 + yRange^2);
    
    % Filter out distances that are too far, no reslicing can be generated
    % for that
    good_d = abs(d_um*1e-3) < xSpan/2;
    min_d_um = min(d_um(good_d));
    max_d_um = max(d_um(good_d));
    
    % Dimensions of the stack to slice
    jumpXYZ = 1e-3; % mm diff(dimensions.x.values(1:2));  
    x = (-xSpan/2):jumpXYZ:(xSpan/2); %mm
    y = (...
        (min_d_um-bufferSize_um):(jumpXYZ*1e3):(max_d_um+bufferSize_um)...
        )/1000; %mm 
    z = (min(dimensions.z.values)):jumpXYZ:(max(dimensions.z.values));

    % Determine where output files will be.
    if isProcessLocallyBeforeUploading
        baseFolder = tifResliceVolumePath;
    else
        baseFolder = OCTVolumesFolder;
    end
    outputFileName = sprintf('%sStackVolume_Iteration%d',baseFolder,whichIterationsToReslice(sI));
    outputFileName = { [outputFileName '_All.tif'], [outputFileName '/']}';

    % Do the reslice, hopefully in the cloud
    if (runningOnJenkins)
        setupParpolOCTPreprocess();
    end
    yOCTReslice(...
        tifVolumePath, ...
        n,x,y,z, ...
        'outputFileOrFolder', outputFileName, ...
        'verbose', true, ...
        'appendToDimensions',appendToDimensions ...
        );
end
fprintf('%s Done!\n',datestr(now));

%% Cleanup
if isProcessLocallyBeforeUploading
    fprintf('%s Uploading resliced volume to cloud...\n',datestr(now));
    l = awsls(tifResliceVolumePath);
    for i=1:length(l)
        awsCopyFileFolder([tifResliceVolumePath l{i}],[OCTVolumesFolder l{i}]);
    end
   
    fprintf('%s Deleting temporary volume from storage...\n',datestr(now));
    rmdir(baseTmpFolder,'s');
end

%% Remove fine alignment for each slide if required
slideIterations = [scJson.sections.iterations];
slideNames = [scJson.sections.names];
isKeepSlides = zeros(size(slideNames),'logical');
for sI = 1:length(whichIterationsToReslice)
    isKeepSlides = isKeepSlides | (slideIterations == whichIterationsToReslice(sI));
end
slidePaths = cellfun(@(x)([subjectFolder '/Slides/' x '/']),slideNames(isKeepSlides),'UniformOutput',false);

scrapFineAlignment(slidePaths);

%% Run pre-process of volume in protected memory
function preprocessVolume(OCTVolumesFolder)
    OCTVolumesFolder_ = OCTVolumesFolder; %#ok<NASGU>
    stitchVolume;
end