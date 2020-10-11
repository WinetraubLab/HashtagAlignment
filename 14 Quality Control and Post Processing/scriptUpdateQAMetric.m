% This script updates QA metric

%% Inputs

% Set subject path an slide/section programaticaly
lib = 'LG';
subjectPath = s3SubjectPath('01',lib); % Get latest subject path
sectionName = 'Slide01_Section01';

% Set to true to override selection above and let user select subject using
% a dialog box
if true
    subjectPath = '';
    sectionName = '';
else
    sectionPath = awsModifyPathForCompetability([subjectPath '/Slides/' sectionName '/']);
end

%% Prompt user to get information
if isempty(subjectPath)
    dims = [1 80];

    % Select subject path
    [subjectPaths, subjectNames] = s3GetAllSubjectsInLib(lib);
    [index, tf] = listdlg('PromptString','Choose Subject', ...
        'ListString',subjectNames,'SelectionMode','single');  
    if ~tf
        return; % We are done
    end    
    subjectPath = subjectPaths{index};
    
    % Select section name
    [sectionPaths, sectionNames] = s3GetAllSlidesOfSubject(subjectPath);
    [index, tf] = listdlg('PromptString','Choose Section', ...
        'ListString',sectionNames,'SelectionMode','single');  
    if ~tf
        return; % We are done
    end    
    sectionPath = sectionPaths{index};
    sectionName = sectionNames{index};
end

%% Load QA, update and save
json = awsReadJSON([sectionPath 'SlideConfig.json']);

QA = getImagePairVisualQualityMetric(json.QAInfo);
if isempty(QA)
    disp('User aborted, not saving');
    return;
end
json.QAInfo = QA;

% Save
awsWriteJSON(json,[sectionPath 'SlideConfig.json']);