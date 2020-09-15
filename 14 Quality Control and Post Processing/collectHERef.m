
%% Read Configuration Data, read all jsons
jsons = s3LoadAllSubjectSectionJSONs(subjectPath_,sectionName_);

%% Histology Image
jsons.slideConfig.data.alignedImagePath_Histology = 'HistologyAligned.tif';
slideFolder = [fileparts(jsons.slideConfig.path) '/'];

histFilePath = awsModifyPathForCompetability(...
    [slideFolder jsons.slideConfig.data.histologyImageFilePath]);
ds = fileDatastore(histFilePath,'ReadFcn',@imread);
imHist = ds.read();

%% Recolor histology to the standard coloring scheme
[H,E] = calculateHERef(imHist);
HRef = [HRef H];
ERef = [ERef E];
