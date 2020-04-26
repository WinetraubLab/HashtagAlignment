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

% Jenkins override of inputs
if exist('filesInTestingSet_','var')
    filesInTestingSet = filesInTestingSet_;
end
if exist('patchFolder_','var')
    patchFolder = patchFolder_;
end

%% Setup Directories
if (~strncmp(patchFolder,'//',2) && ~patchFolder(2) == ':')
    % Path is relative, make it absolute
    patchFolder = awsModifyPathForCompetability([pwd '/' patchFolder '/']);
else
    patchFolder = awsModifyPathForCompetability([patchFolder '/']);
end

outputFolderTrain = [patchFolder 'train/'];
outputFolderTest = [patchFolder 'test/'];
outputFolderValidate = [patchFolder 'val/'];

% Clear output folders
combo = {outputFolderTrain,outputFolderTest,outputFolderValidate};
for i=1:length(combo)
    if exist(combo{i},'dir')
        rmdir(combo{i},'s');
    end
    awsMkDir(combo{i});
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