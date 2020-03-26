function updateWasAlignmentSuccessful(slidePath)
% This function adds wasAlignmentSuccessful to slides that where aligned
% manually (for LC & LD)
% Written at Jan 25, 2020.

%% Load Data
if ~exist('slidePath','var')
    slidePath = [s3SubjectPath('03','LD') 'Slides/Slide01_Section01/'];
end
slideConfigPath = [slidePath 'SlideConfig.json'];

slideConfigJson = awsReadJSON(slideConfigPath);

if ~isfield(slideConfigJson,'FMHistologyAlignment')
    disp('No FMHistologyAlignment');
    return;
end

if isfield(slideConfigJson.FMHistologyAlignment,'wasAlignmentSuccessful')
    % No need to update
end

%% Write
slideConfigJson.FMHistologyAlignment.wasAlignmentSuccessful = true;
awsWriteJSON(slideConfigJson,slideConfigPath);