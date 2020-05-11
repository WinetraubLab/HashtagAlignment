% This script sorts patches to train - test - validate folders.
% Please be sure to run scriptGeneratePatches before running this script to
% generate patches.

%% Inputs

% Where to write patches to:
outputFolder_ = 'Patches/';

% All patches are used for training, except patches with these in their
% filenames, these ones are used for testing
% (ignores the 0/1 number at the begining for flipped images
filesInTestingSet = {'LE-01','LE-03','LF'};

%% Jenkins 
%This function updates all input varible names that have name_ like this:
%name = name_ (jenkins override of input)
setVariblesFromJenkins(); 

%% Set Which files go to which set
% Get file names, remove directories
d = dir(outputFolder_);
isdir = [d.isdir];
fileNames = {d.name};
fileNames(isdir) = [];
fileNames(~cellfun(@(x)(contains(x,'.jpg')),fileNames)) = []; % Remove non images
fileNames = fileNames(:);
filePaths = cellfun(@(x)([outputFolder_ x]),fileNames(:),'UniformOutput',false);

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
if (~strncmp(outputFolder_,'//',2) && ~outputFolder_(2) == ':')
    % Path is relative, make it absolute
    outputFolder_ = awsModifyPathForCompetability([pwd '/' outputFolder_ '/']);
else
    outputFolder_ = awsModifyPathForCompetability([outputFolder_ '/']);
end

if isConcatinateOCTHistologyImages
    outputFolderTrain = [outputFolder_ 'train/'];
    outputFolderTest = [outputFolder_ 'test/'];
    combo = {outputFolderTrain,outputFolderTest,[outputFolder_ 'val/']};
else
    outputFolderTrain = [outputFolder_ 'train'];
    outputFolderTest = [outputFolder_ 'test'];
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