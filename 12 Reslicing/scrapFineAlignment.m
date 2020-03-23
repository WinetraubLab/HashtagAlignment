function scrapFineAlignment(subjectPath)
% This function clears all fine alignment for sections of subject.
% After reslicing OCT, fine alignment needs to be recomputed from scatch.
% This script make sure fine alignments are cleared.
% INPUTS:
%   subjectPath / slidePaths - can be a string containing path to subject
%   or cell array with slide paths to process

%% Input checks
if ~exist('subjectPath','var')
    subjectPath = s3SubjectPath('17','LE');
end

if ischar(subjectPath)
    % Get all slides
    slidePaths = s3GetAllSlidesOfSubject(subjectPath);
elseif iscell(subjectPath)
    slidePaths = subjectPath;
    subjectPath = [];
end

%% Go over all slides, scap fine alignment
for i=1:length(slidePaths)
    slideConfigPath = [slidePaths{i} 'SlideConfig.json'];
    if ~awsExist(slideConfigPath,'var')
        continue;
    end
    slideConfig = awsReadJSON(slideConfigPath);
    
    if isfield(slideConfig.FM,'singlePlaneFit_FineAligned')
        slideConfig.FM = rmfield(slideConfig.FM,'singlePlaneFit_FineAligned');
        slideConfig = rmfield(slideConfig,'QAInfo');
        slideConfig = rmfield(slideConfig,'alignedImagePath_OCT');
        slideConfig = rmfield(slideConfig,'alignedImagePath_Histology');
        slideConfig = rmfield(slideConfig,'FMOCTAlignment');
        awsWriteJSON(slideConfig,slideConfigPath);
    end
end