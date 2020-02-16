function [sectionPathsOut, subjectPathsOut] = ...
    s3GetAllGoodSectionsInLibrary(libraryNames)
% Returns subject & section paths to all libraries with done sections.
% Sorted by subject name
% INPUTS:
%   libraryName - can be a string or a cell containing library names:
%       {'LA','LB'}

%% Input checks
libraryNames = {'LE'};

if ischar(libraryNames)
    libraryNames = {libraryNames};
end
libraryNames = sort(libraryNames);

%% Get all subejcts in all libraries
subjectPaths = {};
for i=1:length(libraryNames)
    s = s3GetAllSubjectsInLib(libraryNames{i});
    subjectPaths = [subjectPaths; s(:)]; %#ok<AGROW>
end
subjectPaths = sort(subjectPaths);

%% Find all sections in these subjects
subjectPathsOut = {};
sectionPathsOut = {};
for i=1:length(subjectPaths)
    s = s3GetAllSlidesOfSubject(subjectPaths{i});
    sectionPathsOut = [sectionPathsOut; s(:)]; %#ok<AGROW>
    subjectPathsOut = [subjectPathsOut; repmat(subjectPaths(i),length(s),1)]; %#ok<AGROW>
end

%% Find which sections are good
isSectionBad = zeros(size(sectionPathsOut),'logical');
fprintf('Processing %d sections, wait for 20 starts [ ',length(sectionPathsOut));
for i=1:length(sectionPathsOut)
    if mod(i,round(length(sectionPathsOut)/20)) == 0
        fprintf('* ');
    end
    
    slideConfigFilePath = awsModifyPathForCompetability(...
        [sectionPathsOut{i} '/SlideConfig.json']);
    
    % Does slide config exist?
    if ~awsExist(slideConfigFilePath,'File')
       isSectionBad(i) = true; continue;
    end
    
    json = awsReadJSON(slideConfigFilePath);
    
    % Do we have histology scanned?
    if ~isfield(json,'histologyImageFilePath')
        isSectionBad(i) = true; continue;
    end
    
    continue; %Don't check do anymore
    
    % Did alignment ran?
    if ~isfield(json,'alignedImagePath_Histology')
        isSectionBad(i) = true; continue;
    end
end
fprintf(']. Done!\n');

% Delete bad section
sectionPathsOut(isSectionBad) = [];
subjectPathsOut(isSectionBad) = [];
