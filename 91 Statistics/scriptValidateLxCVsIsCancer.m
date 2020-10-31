% This script validates caner healthy vs non healthy is in agreement with
% cancer name

libraryNames = {'LC','LD','LE','LF','LG','LH'};
st = loadStatusReportByLibrary(libraryNames);

LxC = cellfun(@(x)(contains(x,'LGC') | contains(x,'LHC')),st.subjectNames);

IsHealthVsLxCConflict = (st.isSampleHealthy == LxC);
subjectsWithConflict = unique(st.subjectNames(IsHealthVsLxCConflict));

%% Print results
fprintf('These subjects have conflict between Subject.json and LxC classification:\n   ');
for i=1:length(subjectsWithConflict)
    fprintf('%s,',subjectsWithConflict{i})
end
fprintf('\n');

%% Fix issues
% You can manualy set subjectsWithConflict = {'LC-01'} if you would like to
% change the identity of this sample specifically.
for i=1:length(subjectsWithConflict)
    ii = find(cellfun(@(x)(strcmp(x,subjectsWithConflict{i})),st.subjectNames),1,'first');
    subjectJsonPath = awsModifyPathForCompetability([st.subjectPahts{ii} '/Subject.json']);
    
    json = awsReadJSON(subjectJsonPath);
    
    an = questdlg([subjectsWithConflict{i} ' has sampleType as: "' json.sampleType '". is it healthy?'],'?','Healthy','Tumor','Skip','Skip');
    
    if ~strcmp(an,'Skip') && ~isempty(an) % Update unless skip
        disp(['Updating ' subjectsWithConflict{i} ' to ' an]);
        json.sampleType = an;
        awsWriteJSON(json,subjectJsonPath);
    end
end
    