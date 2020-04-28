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

%% Set Which files go to which set
% Get file names, remove directories
d = dir(patchFolder);
isdir = [d.isdir];
fileNames = {d.name};
fileNames(isdir) = [];
filePaths = cellfun(@(x)([patchFolder x]),fileNames(:),'UniformOutput',false);
fileNames(~cellfun(@(x)(contains(x,'.jpg')),fileNames)) = []; % Remove non images
fileNames = fileNames(:);

isTraining = zeros(size(fileNames),'logical');
for i=1:length(isTraining)
    isInTesting = cellfun(@(x)(contains(fileNames{i},x)),filesInTestingSet);
    if ~any(isInTesting)
        isTraining(i) = true;
    end
end

% Figure out if both images are concatinated in the same file?
isAType = cellfun(@(x)(contains(x,'_A.')),fileNames);
isBType = cellfun(@(x)(contains(x,'_B.')),fileNames);
if sum(isAType) == sum(isBType)
    if (sum(isAType) > 0)
        isConcatinateOCTHistologyImages = false;
    else
        isConcatinateOCTHistologyImages = true;
    end
else
    error('This should never happen');
end

%% Setup Directories
if (~strncmp(patchFolder,'//',2) && ~patchFolder(2) == ':')
    % Path is relative, make it absolute
    patchFolder = awsModifyPathForCompetability([pwd '/' patchFolder '/']);
else
    patchFolder = awsModifyPathForCompetability([patchFolder '/']);
end

if isConcatinateOCTHistologyImages
    outputFolderTrain = [patchFolder 'train/'];
    outputFolderTest = [patchFolder 'test/'];
    combo = {outputFolderTrain,outputFolderTest,[patchFolder 'val/']};
else
    outputFolderTrain = [patchFolder 'train'];
    outputFolderTest = [patchFolder 'test'];
    combo = {[outputFolderTrain '_A'],[outputFolderTrain '_B'],...
        [outputFolderTest '_A'],[outputFolderTest '_B']};
end

% Clear output folders
for i=1:length(combo)
    if exist(combo{i},'dir')
        rmdir(combo{i},'s');
    end
    awsMkDir(combo{i});
end

%% Move files around - concatinated mode
if isConcatinateOCTHistologyImages
    for i=1:length(filePaths)
        if (isTraining(i))
            movefile(filePaths{i},outputFolderTrain)
        else
            %copyfile(filePaths{i},outputFolderValidate)
            movefile(filePaths{i},outputFolderTest)
        end
    end
else
    for i=1:length(filePaths)
        if (isAType(i))
            pref = '_A';
        else
            pref = '_B';
        end
        
        [~,fileName,fileType] = fileparts(filePaths{i});
        if (isTraining(i))
            toFilePath = awsModifyPathForCompetability(...
                [outputFolderTrain pref '/' strrep(fileName,pref,'') fileType]);
            movefile(filePaths{i},toFilePath);
        else
            toFilePath = awsModifyPathForCompetability(...
                [outputFolderTest pref '/' strrep(fileName,pref,'') fileType]);
            movefile(filePaths{i},toFilePath);
        end
    end
end