% This script validates caner healthy vs non healthy is in agreement with
% cancer name

%% Load Data
libraryNames = s3GetAllLibs();
st = loadStatusReportByLibrary(libraryNames);

%% Discover & deal with healthy / cancer conflicts
LxC = cellfun(@(x)(contains(x,'LGC') | contains(x,'LHC') | contains(x,'LIC')),st.subjectNames);

IsHealthVsLxCConflict = (st.isSampleHealthy == LxC);
subjectsWithConflict = unique(st.subjectNames(IsHealthVsLxCConflict));

%Print results
fprintf('These subjects have conflict between Subject.json and LxC classification:\n   ');
for i=1:length(subjectsWithConflict)
    fprintf('%s,',subjectsWithConflict{i})
end
fprintf('\n');

%Fix Cancer issues
% You can manualy set subjectsWithConflict = {'LC-01'} if you would like to
% change the identity of this sample specifically.
for i=1:length(subjectsWithConflict)
    ii = find(cellfun(@(x)(strcmp(x,subjectsWithConflict{i})),st.subjectNames),1,'first');
    subjectJsonPath = awsModifyPathForCompetability([st.subjectPahts{ii} '/Subject.json']);
    
    json = awsReadJSON(subjectJsonPath);
    
    an = questdlg(sprintf('%s has sampleType as: %s. is it healthy?',...
        subjectsWithConflict{i} , json.sampleType),'?','Healthy','Tumor','Skip','Skip');
    
    if ~strcmp(an,'Skip') && ~isempty(an) % Update unless skip
        disp(['Updating ' subjectsWithConflict{i} ' to ' an]);
        json.sampleType = an;
        awsWriteJSON(json,subjectJsonPath);
    end
end

%% Fix if section is usable in ML but is not fresh human sample - that should be a mistake
subjectsWithConflict = unique (st.subjectNames(st.isUsableInML==true & ~st.isFreshHumanSample));

% Print results
fprintf('These subjects have conflict between SubjectisUsableInML and LxC isFreshHumanSample:\n   ');
for i=1:length(subjectsWithConflict)
    fprintf('%s,',subjectsWithConflict{i})
end
fprintf('\n');

% Fix
for i=1:length(subjectsWithConflict)
    ii = find(cellfun(@(x)(strcmp(x,subjectsWithConflict{i})),st.subjectNames),1,'first');
    subjectJsonPath = awsModifyPathForCompetability([st.subjectPahts{ii} '/Subject.json']);
    
    json = awsReadJSON(subjectJsonPath);
    
    an = questdlg(sprintf('%s is marked as usable in ml, but isFreshHumanSample is %d', ...
        subjectsWithConflict{i} ,json.isFreshHumanSample),'?','Not Fresh Sample','Is Fresh Sample','Skip','Skip');
    
    if ~strcmp(an,'Skip') && ~isempty(an) % Update unless skip
        disp(['Updating ' subjectsWithConflict{i} ' to ' an]);
        json.isFreshHumanSample = strcmp(an,'Is Fresh Sample');
        awsWriteJSON(json,subjectJsonPath);
    end
end