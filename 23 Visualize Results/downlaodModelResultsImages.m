function [modelToLoad,modelToLoadFolder] = downlaodModelResultsImages(modelName,isCorrectAspectRatio2To1,outputFolder,scaleBar)
% This function downloads test and train images from aws. Saves locally for
% further analysis
% INPUTS:
%   modelName - a partial string helping us search for the right model.
%       Example: "10x Yonatan Pix2Pix"
%       If more then one model exists with the same match, will pull latest
%   isCorrectAspectRatio2To1 - if images are a square with 2 to 1 aspect
%       ratio, set this flag to true (default) and will illongate
%       accordingly
%   outputFolder - where to write files, default is '\tmp\'
%   scaleBar - Should we add scale bar to histology images? if so set
%       scaleBar to number of microns to put scalebar. If not set to 0.
%       default: 100 [um]
%
% OUTPUTS:
%   modelToLoad - folder name that was loaded

%% Input checks

if ~exist('modelName','var') || isempty(modelName)
    modelName = 'Yonatan';
end

if ~exist('isCorrectAspectRatio2To1','var') || isempty(isCorrectAspectRatio2To1)
    isCorrectAspectRatio2To1 = true;
end

if ~exist('outputFolder','var') || isempty(outputFolder)
    outputFolder = [pwd '/tmp'];
end

if ~exist('scaleBar','var') || isempty(scaleBar)
    scaleBar = 100;
end

%% Figure out the main folder
datasetBaseDirectory = s3SubjectPath('','_MLModels');

% Find the right model
models = awsls(datasetBaseDirectory);
isModelMatch = cellfun(@(x)(contains(x,modelName,'IgnoreCase',true)),models);
modelToLoad = models{find(isModelMatch,1,'last')};
modelToLoadFolder = [datasetBaseDirectory modelToLoad];

% Find right sub-folder
modelResultsFolder = [modelToLoadFolder 'results/'];
subFolderNames = awsls(modelResultsFolder);
if length(subFolderNames) > 1
    error('Expected only one folder here: %s, found %d. Don''t know where to go from here - which folder should I pick?',...
        modelResultsFolder,length(subFolderNames));
end

%% Get all the images locally

% Make dir
awsMkDir(outputFolder,true);

% Copy test folder
trainingModelFolder = [modelResultsFolder subFolderNames{1} 'test_latest/images/'];
copyImages(trainingModelFolder,outputFolder,'test_');

% Copy train folder
trainingModelFolder = [modelResultsFolder subFolderNames{1} 'train_latest/images/'];
copyImages(trainingModelFolder,outputFolder,'train_');

%% Correct 2 to 1 ratio & scalebar if needed

% Load data to figure out scale bar
json = awsReadJSON([modelToLoadFolder '/dataset_oct_histology/original_image_pairs/DatasetConfig.json']);
imagesPixelSize_um = 2; %json.imagesPixelSize_um; %TBD - this is true for 10x images only
    
% Loop for each image and process
ds = fileDatastore(outputFolder,'ReadFcn',@imread);
for i=1:length(ds.Files)
    fn = ds.Files{i};
    
    % Load
    im = ds.read();
    
    % Read real image B, use that to mask
    imR = imread(strrep(fn,'_fake_B.','_real_B.'));
    
    if any(size(im) ~= size(imR))
        error('here');
    end
    
    % Remove completly masked areas
    msk = all(imR==0,3);
    msk = all(msk,2);
    im  = im(~msk,:,:);
    
    msk = all(imR==0,3);
    msk = all(msk,1);
    im  = im(:,~msk,:);
    
    if isempty(im)
        %Nothing left
        continue;
    end
    
    % Resize if needed
    sz = [size(im,1) size(im,2)];
    if isCorrectAspectRatio2To1
        im = imresize(im, sz.*[1 2], 'Antialiasing', true, 'method', 'cubic');
    end
    
    % Add scale bar if needed
    if scaleBar > 0 && contains(fn,'B.png') % Add scalebar to histology only
        scalebarLength = scaleBar/imagesPixelSize_um;
        im(end-(10:15),15+(1:scalebarLength),:) = 256;
    end
    
    % Save
    imwrite(im,fn);
end 

function copyImages(sourceFoloder,destFolder,prefix)

% Copy files to new folder
destFolder1 = [destFolder '/' prefix '/'];
awsMkDir(destFolder1,true);

% Copy files
awsCopyFileFolder(sourceFoloder,destFolder1);

[fileNames,filePaths] = awsls(destFolder1);

% Remove all non image files
ii = cellfun(@(x)(~contains(x,'.png')),filePaths);
fileNames(ii) = [];
filePaths(ii) = [];

if mod(length(fileNames),3) ~= 0
    error('No equal number of real A, real B and fake B');
end

for i=1:length(fileNames)
    awsCopyFileFolder(filePaths{i},[destFolder '/' prefix fileNames{i}]);
end

awsRmDir(destFolder1);
