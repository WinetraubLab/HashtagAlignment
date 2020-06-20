% This script generates dataset for ML models

%% Inputs - set defaults
magnificationName = '10x';
tagName = '';

octBScanToUseAroundCenter = [];
isAverageOCTBScans = [];

filesInTestingSet = {'LF','LG'};

%% Jenkins 
%This function updates all input varible names that have name_ like this:
%name = name_ 
%(jenkins override of input)
setVariblesFromJenkins(); 

%% Generate dataset name & general information
dataSetName = sprintf('%s %s %s', datestr(now,'yyyy-mm-dd'), magnificationName,tagName);
dataSetName = strtrim(dataSetName);

pixSize_um = magnificationToPixelSizeMicrons (magnificationName);

localDirectory = [pwd '\dataset_oct_histology\'];
mainUploadDirectory = awsModifyPathForCompetability(sprintf('%s/%s/', ...
        s3SubjectPath('','_Datasets'), ...
        dataSetName),true);
    
% Clear local directory
awsMkDir(localDirectory);
    
%% Generate images & patches - main dataset

% Get images
fprintf('%s Gather image pairs OCT Histology\n',datestr(datetime));
alignedImagesFolder = [localDirectory 'original_image_pairs\'];
gatherAlignedImagesFromAllSubjects(...
    alignedImagesFolder,octBScanToUseAroundCenter,...
    isAverageOCTBScans, pixSize_um);

% Update dataset with test spec
json = awsReadJSON([alignedImagesFolder 'DatasetConfig.json']);
json.filesInTestingSet = filesInTestingSet;
awsWriteJSON(json,[alignedImagesFolder 'DatasetConfig.json']);

% Generate patches
fprintf('%s Generate 256X256 Patches Dataset ...\n',datestr(datetime));
outputFolder = generatePatchesFromImages(alignedImagesFolder,[], [256 256]);
fprintf('%s Devide to train test dataset ...\n',datestr(datetime));
sortImagesTrainTest(outputFolder,filesInTestingSet);

fprintf('%s Generate 256X256 Patches, aspect ratio 2-1 Dataset ...\n',datestr(datetime));
outputFolder = generatePatchesFromImages(alignedImagesFolder,[], [256, 256], [1,0.5]);
fprintf('%s Devide to train test dataset ...\n',datestr(datetime));
sortImagesTrainTest(outputFolder,filesInTestingSet);

fprintf('%s Generate 512X256 Patches Dataset ...\n',datestr(datetime));
outputFolder = generatePatchesFromImages(alignedImagesFolder,[], [256, 512]);
fprintf('%s Devide to train test dataset ...\n',datestr(datetime));
sortImagesTrainTest(outputFolder,filesInTestingSet);

fprintf('%s Generate 1024X512 Patches Dataset ...\n',datestr(datetime));
outputFolder = generatePatchesFromImages(alignedImagesFolder,[], [512, 1024]);
fprintf('%s Devide to train test dataset ...\n',datestr(datetime));
sortImagesTrainTest(outputFolder,filesInTestingSet);

% Generate dataset view
fprintf('%s Generate Dataset View ...\n',datestr(datetime));
combineOCTHistToOneImage(alignedImagesFolder,[localDirectory '\original_image_pairs_view_for_user']);

%% Copy to S3
fprintf('%s Upload to cloud ...\n',datestr(datetime));
awsCopyFileFolder(localDirectory, mainUploadDirectory, false);
fprintf('%s All Done!\n',datestr(datetime));