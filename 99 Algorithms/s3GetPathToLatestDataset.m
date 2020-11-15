function [datasetPath, datasetName] = s3GetPathToLatestDataset (imageResolution,datasetTag)
% imageResolution can be '2x','4x','10x' etc
% datasetTag can be additional search phrase, or can be empty (default)

%% Inputs
if ~exist('datasetTag','var')
    datasetTag = '';
end
datasetTag = strtrim(datasetTag);

if ~exist('imageResolution','var') || isempty(imageResolution)
    imageResolution = '10x';
end

%% Get all datasets in base directory
datasetBaseDirectory = s3SubjectPath('','_Datasets');
datasetNames = awsls(datasetBaseDirectory);

isContainImageResolution = cellfun(@(x)(contains(x,imageResolution,'IgnoreCase',true)),datasetNames);
isContainTag = cellfun(@(x)(contains(x,datasetTag,'IgnoreCase',true)),datasetNames);

if ~any(isContainImageResolution & isContainTag)
    error('Colud not find any data set with resulution "%s" and tag "%s"',imageResolution,datasetTag);
end

datasetNames = datasetNames(isContainImageResolution & isContainTag);

datasetPath = awsModifyPathForCompetability([datasetBaseDirectory '/' datasetNames{end} '/'],true); 
datasetName = strrep(datasetNames{end},'/','');
