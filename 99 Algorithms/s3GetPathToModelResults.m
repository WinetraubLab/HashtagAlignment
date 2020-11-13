function [modelBasePath, resultsPath] = s3GetPathToModelResults (modelName,executerName,otherIdentifier)
% This function will return a link to ml dataset
% Inputs:
%   modelName - name of the model trained (pix2pix, oct2hist etc). Can be
%       empty if any model
%   executerName - name of the person executed the model (Yonatan, Itamar
%       etc). Can be empty if any executer
%   otherIdentifier - any string to search for. Can be left enpty
% OUTPUTS:
%   modelBasePath - Path to the model
%   resultsPath - Path to the results portion of the model
%   

%% Inputs check
if ~exist('modelName','var')
    modelName = [];
end

if ~exist('executerName','var')
    executerName = [];
end

if ~exist('otherIdentifier','var')
    otherIdentifier = [];
end

%% Get all datasets in base directory
datasetBaseDirectory = s3SubjectPath('','_MLModels');
datasetNames = awsls(datasetBaseDirectory);

%% Sort out which models is a match
if ~isempty(modelName)
    isModelNameMatch = cellfun(@(x)(contains(x,modelName,'IgnoreCase',true)),datasetNames);
else
    isModelNameMatch  = ones(size(datasetNames),'logical');
end

if ~isempty(executerName)
    isExecuterNameMatch = cellfun(@(x)(contains(x,executerName,'IgnoreCase',true)),datasetNames);
else
    isExecuterNameMatch  = ones(size(datasetNames),'logical');
end

if ~isempty(otherIdentifier)
    isOtherIdentifierMatch = cellfun(@(x)(contains(x,otherIdentifier,'IgnoreCase',true)),datasetNames);
else
    isOtherIdentifierMatch  = ones(size(datasetNames),'logical');
end

isAllMatch = isModelNameMatch & isExecuterNameMatch & isOtherIdentifierMatch;

if ~any(isAllMatch)
    error('Colud not find any model with modelName "%s", executerName "%s", otherIdentifier "%s"',...
        modelName,executerName,otherIdentifier);
end

modelBasePath = awsModifyPathForCompetability([datasetBaseDirectory '/' datasetNames{find(isAllMatch,1,'last')} '/'],true); 

%% Look into results folder
[resultsName,resultsPath] = awsls([modelBasePath '/results']);

if isempty(resultsPath)
    error('Didn''t find any results in "%s"',modelBasePath);
end

if length(resultsName) > 1
    % Figure out which model to get
    ii = cellfun(@(x)(contains(x,modelName,'IgnoreCase',true)),resultsName);
    if sum(ii) ~= 1
        error('Got a few model results in "%s", can''t figure out which to choose', ...
            [modelBasePath '/results']);
    end
    resultsPath = resultsPath{ii};
else
    resultsPath = resultsPath{1};
end
