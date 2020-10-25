function updateQA(slidePath)
% Update QA structure with missing fileds
% Written at Oct 10, 2020.

%% Load Data
if ~exist('slidePath','var')
    slidePath = [s3SubjectPath('16','LE') 'Slides/Slide07_Section01/'];
end
slideConfigPath = [slidePath 'SlideConfig.json'];
slideConfigJson = awsReadJSON(slideConfigPath);

if ~isfield(slideConfigJson,'QAInfo')
    return; % This section doesn't have QA
end

%% Update
isUpdateNeeded = false;
if ~isfield(slideConfigJson.QAInfo.OCTImageQuality,'IsDermisVisible')
    % Make a best guess
    slideConfigJson.QAInfo.OCTImageQuality.IsDermisVisible = ...
        slideConfigJson.QAInfo.OCTImageQuality.IsOverallImageQualityGood & ...
        slideConfigJson.QAInfo.OCTImageQuality.IsEpitheliumVisible;
    isUpdateNeeded = true;
end

if ~isfield(slideConfigJson.QAInfo.HandEImageQuality_InOverlapArea,'TissueBreakageOrHolesPresent')
    % Make a best guess
    slideConfigJson.QAInfo.HandEImageQuality_InOverlapArea.TissueBreakageOrHolesPresent = false;
    isUpdateNeeded = true;
end

%% Write
if isUpdateNeeded
    awsWriteJSON(slideConfigJson,slideConfigPath);
end