% Collect general section statistics

%% Inputs
datasetTag = ''; % Which dataset tag to load? Will load the latest unless specific date is writen in tag

isGroupBySubject = true; % Would you like to group results by subject

%% Load st structure
[datasetPath, datasetName] = s3GetPathToLatestDataset('10x',datasetTag);
stStructurePath = [datasetPath '/original_image_pairs/StatusReportBySection.json'];
st = awsReadJSON(stStructurePath);

% For backward compatibility, can remove this section in the future.
if ~isfield(st,'isFreshHumanSample')
    st.isFreshHumanSample = ...
        ~cellfun(@(x)(contains(x,'LGM') | contains(x,'LFM')),st.subjectNames);
end

%% Compute statistics
goodI = st.isFreshHumanSample & st.isSampleHealthy;

if isGroupBySubject
    [uSubjectNames, ~, uI] = unique(st.subjectNames);

    overall = zeros(size(uSubjectNames));
    usedInML = overall;
    trainSet = overall;
    testSet = overall;
    for i=1:length(uSubjectNames)
       overall(i) = any(goodI(uI == i));
       usedInML(i) = sum(st.isUsableInML(uI == i & goodI));
       trainSet(i) = any(st.mlPhase(uI == i & goodI) < 0);
       testSet(i) = any(st.mlPhase(uI == i & goodI) > 0);
    end

    nOverall = sum(overall);
    subjectThreshold = usedInML>=1;  % Subjects with at least x good sections. 
    nUsedInML = sum(subjectThreshold);
    nTrainSet = sum(trainSet);
    nTestSet = sum(testSet);
    avgGoodSectionsInGoodSubject = mean(usedInML(subjectThreshold));
else
    nOverall = sum(goodI);
    nUsedInML = sum(st.isUsableInML(goodI));
    nTrainSet = sum(st.mlPhase(goodI) < 0);
    nTestSet = sum(st.mlPhase(goodI) > 0);
end

%% Print results
if (isGroupBySubject)
    txt = 'Subjects';
else
    txt = 'Sections';
end

fprintf('\nStatistics for "%s" (by %s):\n',datasetName,txt);
fprintf('%d %s Scanned\n',nOverall,txt);
fprintf('%d of %s are Usable in ML (%.0f%% of Scanned)\n',nUsedInML,txt,nUsedInML/nOverall*100);
fprintf('%d of %s are in Training Set (%.0f%% of Usable)\n',nTrainSet,txt,nTrainSet/nUsedInML*100);
fprintf('%d of %s are in Testing Set (%.0f%% of Usable)\n',nTestSet,txt,nTestSet/nUsedInML*100);
fprintf('\n');

if isGroupBySubject
    fprintf('%.0f good sections per good subject on average.\n',avgGoodSectionsInGoodSubject);
end
