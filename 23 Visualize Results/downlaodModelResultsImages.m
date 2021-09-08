function [modelToLoadFolder] = downlaodModelResultsImages(...
    resultsPath,isCorrectAspectRatio2To1,outputFolder,scaleBar,st,additionalFilter)
% This function downloads test and train images from aws. Saves locally for
% further analysis
% INPUTS:
%   resultsPath - path to model result, get using s3GetPathToModelResult
%   isCorrectAspectRatio2To1 - if images are a square with 2 to 1 aspect
%       ratio, set this flag to true (default) and will illongate
%       accordingly
%   outputFolder - where to write files, default is '\tmp\'. Output folder
%       contains training and testing set results
%   scaleBar - Should we add scale bar to histology images? if so set
%       scaleBar to number of microns to put scalebar. If not set to 0.
%       default: 100 [um]
% OPTIONAL INPUTS:
% The following inputs are optional if you would like to download only part
% of the libery instead of all of it.
%   st - st structure of all sections. Default is [], meaning no filter
%   additionalFilter - vector to filter. Sections will be picked out of
%       st.<parameter>(additionalFilter==1), Default is no filter
%
% OUTPUTS:
%   modelToLoadFolder - folder name that was loaded

%% Input checks

if ~exist('resultsPath','var') || isempty(resultsPath)
    [~,resultsPath] = s3GetPathToModelResult('Yonatan');
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

if ~exist('st','var') || isempty(st)
    st = [];
    additionalFilter = [];
end

modelToLoadFolder = awsModifyPathForCompetability([resultsPath '../../'],false);

%% Get all the images locally

% Make dir
awsMkDir(outputFolder,true);

% Copy test folder
trainingModelFolder = [resultsPath '/test_latest/images/'];
copyImages(trainingModelFolder,outputFolder,'test_',st,additionalFilter);

% Copy train folder
trainingModelFolder = [resultsPath '/train_latest/images/'];
copyImages(trainingModelFolder,outputFolder,'train_',st,additionalFilter);

%% Correct 2 to 1 ratio & scalebar if needed

% Load data to figure out scale bar
json = awsReadJSON([modelToLoadFolder '/dataset_oct_histology/original_image_pairs/DatasetConfig.json']);
imagesPixelSize_um = 2; %json.imagesPixelSize_um; %TBD - this is true for 10x images only
    
% Loop for each image and process
% Any fileDatastore request to AWS S3 is limited to 1000 files in 
% MATLAB 2021a. Due to this bug, we have replaced all calls to 
% fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
% 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
ds = imageDatastore(outputFolder,'ReadFcn',@imread);
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

function copyImages(sourceFolder,destFolder,prefix,st,additionalFilter)

% Copy files to new folder
destFolder1 = [destFolder '/' prefix '/'];
awsMkDir(destFolder1,true);

% See if we need to apply a filter
if ~isempty(st)
    [~,fp] = awsls(sourceFolder);
    isKeep = findFilesInST(fp, st, additionalFilter);
    fp(~isKeep) = [];
    awsCopyFileFolder(fp,destFolder1);
else
    % Copy all files
    awsCopyFileFolder(sourceFolder,destFolder1);
end

[fileNames,filePaths] = awsls(destFolder1);

% Remove all non image files
ii = cellfun(@(x)(~contains(x,'.png')),filePaths);
fileNames(ii) = [];
filePaths(ii) = [];

if mod(length(fileNames),3) ~= 0 || length(fileNames) ~= length(filePaths)
    error('No equal number of real A, real B and fake B');
end

for i=1:length(fileNames)
    awsCopyFileFolder(filePaths{i},[destFolder '/' prefix fileNames{i}]);
end

awsRmDir(destFolder1);
