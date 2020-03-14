% This script sorts patches to train - test - validate folders.
% Please be sure to run scriptGeneratePatches before running this script to
% generate patches.

%% Inputs

% Where to write patches to:
patchFolder = 'Patches/';

% Patches up to this subject will be used for training, after for testing
% (ignores the 0/1 number at the begining for flipped images
fileNameToStartTestingSet = 'LE-14';

% Jenkins override of inputs
if exist('fileNameToStartTestingSet_','var')
    fileNameToStartTestingSet = fileNameToStartTestingSet_;
    patchFolder = patchFolder_;
end

%% Setup Directories
patchFolder = awsModifyPathForCompetability([pwd '/' patchFolder '/']);

outputFolderTrain = [patchFolder 'train/'];
outputFolderTest = [patchFolder 'test/'];
outputFolderValidate = [patchFolder 'val/'];

% Clear output folders
combo = {outputFolderTrain,outputFolderTest,outputFolderValidate};
for i=1:length(combo)
    if exist(combo{i},'dir')
        rmdir(combo{i},'s');
    end
    mkdir(combo{i});
end

%% Set Which files go to which set
% Get file names, remove directories
d = dir(patchFolder);
isdir = [d.isdir];
fileNames = {d.name};
fileNames(isdir) = [];
filePaths = cellfun(@(x)([patchFolder x]),fileNames(:),'UniformOutput',false);

%Compare short names to the first subject
fileNames2 = cellfun(@(x)(x(3:end)),fileNames(:),'UniformOutput',false);
isTraining = string(fileNames2) < fileNameToStartTestingSet;

%% Move files around
fprintf('Training: %s to %s. Numbrt of patches: %d (%.1f%%).\n', ...
    fileNames2{find(isTraining==1,1,'first')},fileNames2{find(isTraining==1,1,'last')},...
    sum(isTraining==1),sum(isTraining==1)/length(isTraining)*100)
fprintf('Testing:  %s to %s. Number of patches: %d (%.1f%%).\n', ...
    fileNames2{find(isTraining==0,1,'first')},fileNames2{find(isTraining==0,1,'last')},...
    sum(isTraining==0),sum(isTraining==0)/length(isTraining)*100)

for i=1:length(filePaths)
    if (isTraining(i))
        movefile(filePaths{i},outputFolderTrain)
    else
        copyfile(filePaths{i},outputFolderTest)
        movefile(filePaths{i},outputFolderValidate)
    end
end

