% This script sorts patches to train - test - validate folders.
% Please be sure to run scriptGeneratePatches before running this script to
% generate patches.

%% Inputs

% Where to write patches to:
patchFolder = 'Patches/';

% All patches are used for training, except patches with these in their
% filenames, these ones are used for testing
% (ignores the 0/1 number at the begining for flipped images
filesInTestingSet = {'LE-01','LE-03','LF'};
filesInTestingSet(end+1) = {'LD-03'}; %Temp for testing (TBD TODO: Yonatan to delete)
% Jenkins override of inputs
if exist('filesInTestingSet_','var')
    filesInTestingSet = filesInTestingSet_;
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

isTraining = zeros(size(fileNames),'logical');
for i=1:length(isTraining)
    isInTesting = cellfun(@(x)(contains(fileNames{i},x)),filesInTestingSet);
    if ~any(isInTesting)
        isTraining(i) = true;
    end
end

%% Move files around
for i=1:length(filePaths)
    if (isTraining(i))
        movefile(filePaths{i},outputFolderTrain)
    else
        copyfile(filePaths{i},outputFolderTest)
        movefile(filePaths{i},outputFolderValidate)
    end
end