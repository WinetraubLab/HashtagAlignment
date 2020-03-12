function uploadMarkLinesImageToLog(slidePath)
% This function uploads mark lines overview image to cloud 
% Written at Mar 11, 2020.

%% Input checks
if ~exist('slidePath','var')
    slidePath = [s3SubjectPath('04','LE') 'Slides/Slide03_Section02/'];
end
slidePath = awsModifyPathForCompetability([slidePath '/']);

%% Load Json
slideConfigJsonPath = [slidePath 'SlideConfig.json'];
if ~awsExist(slideConfigJsonPath,'file')
    disp('No Slide Json, skipping')
    return;
end
slideConfigJson = awsReadJSON(slideConfigJsonPath);

if ~isfield(slideConfigJson,'FM')
    disp('No slideConfigJson.FM, skipping')
    return;
end
FM = slideConfigJson.FM;

%% Load fluorescence image
ds = fileDatastore(awsModifyPathForCompetability(...
    [slidePath slideConfigJson.photobleachedLinesImagePath]),'ReadFcn',@imread);
im = ds.read();

%% Save to log
[~,slideName] = fileparts([slidePath(1:(end-1)) '.a']);
subjectFolder = awsModifyPathForCompetability([slidePath '/../../']);
subjectName = s3GetSubjectName(subjectFolder);
logFolder = awsModifyPathForCompetability([subjectFolder '/Log/']);

% Plot what we did to a figure and upload
fig1=figure(100);
drawSlideStatus(im,FM);
title([subjectName ' ' strrep(slideName,'_',' ')]);
awsSaveMatlabFigure(fig1, [logFolder '03 Fluorescence Preprocess/' slideName '.png']);

