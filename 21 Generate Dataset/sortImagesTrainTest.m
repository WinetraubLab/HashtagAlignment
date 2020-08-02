function sortImagesTrainTest(baseFolder,filesInTestingSet)
% This function sorts images to train & test folders
% train_A, test_A contains OCT, _B contains histology.
%   baseFolder - main folder to sort
%   filesInTestingSet - cell array containing template of files to be
%   included in test set, all the rest will be train set

%% Inputs
if ~exist('filesInTestingSet','var') || isempty(filesInTestingSet)
    filesInTestingSet = {}; %Use default
end

if ~exist('baseFolder','var') || isempty(baseFolder)
   baseFolder = [pwd '\dataset_oct_histology\patches_256px_256px\'];
end

isConcatinateOCTHistologyImages = false;

%% Set Which files go to which set
% Get file names, remove directories
d = dir(baseFolder);
isdir = [d.isdir];
fileNames = {d.name};
fileNames(isdir) = [];
fileNames(~cellfun(@(x)(contains(x,'.jpg')),fileNames)) = []; % Remove non images
fileNames = fileNames(:);
filePaths = cellfun(@(x)([baseFolder x]),fileNames(:),'UniformOutput',false);

isTraining = isFilesInTrainingSet(fileNames, filesInTestingSet);

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
    error('# of A files is different from # of B files. This should never happen');
end

%% Setup Directories
if (~strncmp(baseFolder,'//',2) && ~baseFolder(2) == ':')
    % Path is relative, make it absolute
    baseFolder = awsModifyPathForCompetability([pwd '/' baseFolder '/']);
else
    baseFolder = awsModifyPathForCompetability([baseFolder '/']);
end

if isConcatinateOCTHistologyImages
    outputFolderTrain = [baseFolder 'train/'];
    outputFolderTest = [baseFolder 'test/'];
    combo = {outputFolderTrain,outputFolderTest,[baseFolder 'val/']};
else
    outputFolderTrain = [baseFolder 'train'];
    outputFolderTest = [baseFolder 'test'];
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