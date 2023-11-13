% This script downloads dataset to local folder to be viewed by user, it
% copies the OCT vs histology images

%% Inputs
imageResolution = '10x';
datasetTag = '';%'2020-11-10'; % What date this data set was created, leave empty for latest
outputDir = 'tmpDataset';

isRaw = false; % Set to ture to view the raw images, false to download the view for user

%% Gather dataset
datasetPath = s3GetPathToLatestDataset(imageResolution,datasetTag);
awsMkDir([pwd '/' outputDir '/'],true);
if isRaw
    awsCopyFileFolder([datasetPath 'original_image_pairs/'],[outputDir '/']);
else
    awsCopyFileFolder([datasetPath 'original_image_pairs_view_for_user/'],[outputDir '/']);
end