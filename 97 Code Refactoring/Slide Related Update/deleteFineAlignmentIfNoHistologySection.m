function deleteFineAlignmentIfNoHistologySection(slidePath)
% This function deletes fine alignment information if slide doesn't have
% histology section. It cannot be fine aligned!
% Written at May 10, 2020.

%% Load Data
if ~exist('slidePath','var')
    slidePath = [s3SubjectPath('18','LE') 'Slides/Slide05_Section03/'];
end
slideConfigPath = [slidePath 'SlideConfig.json'];

slideConfigJson = awsReadJSON(slideConfigPath);

if isfield(slideConfigJson,'histologyImageFilePath')
    disp('Found Histology, skipping');
    return;
end

slideConfigJson=rmfieldIfExist(slideConfigJson,'FMOCTAlignment');
slideConfigJson=rmfieldIfExist(slideConfigJson,'QAInfo'); % Shouldn't have QA either as it requiers fine alignment
slideConfigJson.FM = rmfieldIfExist(slideConfigJson.FM,'singlePlaneFit_FineAligned');

%% Write
awsWriteJSON(slideConfigJson,slideConfigPath);

function s=rmfieldIfExist(s,fieldName)
if isfield(s,fieldName)
    s = rmfield(s,fieldName);
end