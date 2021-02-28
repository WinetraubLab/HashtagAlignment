% This script downloads dataset to local folder to be viewed by user, it
% copies the OCT vs histology images

%% Inputs
imageResolution = '10x';
datasetTag = '';%'2020-08-15'; % What date this data set was created, leave empty for latest
outputDir = 'tmpDataset';

%% Gather dataset
datasetPath = s3GetPathToLatestDataset(imageResolution,datasetTag);
awsMkDir([pwd '/' outputDir '/'],true);
awsCopyFileFolder([datasetPath 'original_image_pairs_view_for_user/'],[outputDir '/']);