% This script downloads dataset to local folder to be viewed by user

%% Inputs
imageResolution = '10x';
datasetTag = '';%'2020-08-15'; % What date this data set was created, leave empty for latest

%% Gather dataset
datasetPath = getPathToLatestDataset(imageResolution,datasetTag);
awsMkDir([pwd '/tmp/'],true);
awsCopyFileFolder(datasetPath,'tmp/');