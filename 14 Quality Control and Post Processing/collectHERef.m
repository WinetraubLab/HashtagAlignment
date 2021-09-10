
%% Read Configuration Data, read all jsons
jsons = s3LoadAllSubjectSectionJSONs(subjectPath_,sectionName_);

%% Histology Image
jsons.slideConfig.data.alignedImagePath_Histology = 'HistologyAligned.tif';
slideFolder = [fileparts(jsons.slideConfig.path) '/'];

histFilePath = awsModifyPathForCompetability(...
    [slideFolder jsons.slideConfig.data.histologyImageFilePath]);
% Any fileDatastore request to AWS S3 is limited to 1000 files in 
% MATLAB 2021a. Due to this bug, we have replaced all calls to 
% fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
% 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
ds = fileDatastore(histFilePath,'ReadFcn',@imread);
imHist = ds.read();

%% Recolor histology to the standard coloring scheme
[H,E] = calculateHERef(imHist);
HRef = [HRef H];
ERef = [ERef E];
