% This script reslices an OCT volume for a specific iteration, assumes the
% following was already run:
%   1) 01 OCT Preprocess - pre-process volume (optional, this script can
%       reprocess)
%   2) 11 Align OCT to Flourecence Imaging - alignment was calculated

isReProcessOCT = false;
whichIterationsToReslice = 2;
runningOnJenkins = false;

subjectFolder = s3SubjectPath('02');
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

% OCT
[~, dimensions] = yOCTFromTif([OCTVolumesFolder 'VolumeScanAbs/'],[]);

% Stack Config
scJsonFilePath = awsModifyPathForCompetability([subjectFolder '/Slides/StackConfig.json']);
scJson = awsReadJSON(scJsonFilePath);

%% Pre-process volume (if needed)
if isReProcessOCT
   preprocessVolume(OCTVolumesFolder);
end

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
    n = stackAlignment.planeNormal;
    d_um = stackAlignment.planeDistanceFromOCTOrigin_um;
    if (d_um(1) > d_um(end))
        % Sort backwards
        n = -n;
        d_um = -d_um;
    end
    
    % Dimensions of the stack to slice
    xRange = max(dimensions.x.values) - min(dimensions.x.values);
    yRange = max(dimensions.y.values) - min(dimensions.y.values);
    jumpXY = diff(dimensions.x.values(1:2));
    xSpan = sqrt(xRange^2 + yRange^2);
    x = (-xSpan/2):jumpXY:(xSpan/2); %mm
    y = ((min(d_um)-30):(jumpXY*1e3):(max(d_um)+30))/1000; %mm, take some buffer on both ends
    z = dimensions.z.values;

    outputFileName = sprintf('%sStackVolume_Iteration%d',OCTVolumesFolder,whichIterationsToReslice(sI));
    outputFileName = { [outputFileName '_All.tif'], [outputFileName '/']}';

    % Do the reslice, hopefully in the cloud
    if (runningOnJenkins)
        setupParpolOCTPreprocess();
    end
    yOCTReslice(...
        [OCTVolumesFolder 'VolumeScanAbs'], ...
        n,x,y,z, ...
        'outputFileOrFolder',outputFileName ...
        );
end
fprintf('%s Done!\n',datestr(now));


%% Run pre-process of volume in protected memory
function preprocessVolume(OCTVolumesFolder)
    OCTVolumesFolder_ = OCTVolumesFolder; %#ok<NASGU>
    stitchVolume;
end