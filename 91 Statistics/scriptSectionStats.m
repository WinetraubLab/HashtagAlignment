% Collect general section statistics

%% Inputs

% Which dataset tag to load? 
% - Set to '' to load the dataset
% - Set to 'currentLib' to load the current library (not dataset) - this is
%       the most latest dataset.
datasetTag = 'currentLib'; % '2020-11-10'; 

isGroupBySubject = false; % Would you like to group results by subject

%% Load st structure
if strcmp(datasetTag,'currentLib')
    st =loadStatusReportByLibrary();
    datasetName = 'Latest Library';
else
    [datasetPath, datasetName] = s3GetPathToLatestDataset('10x',datasetTag);
    stStructurePath = [datasetPath '/original_image_pairs/StatusReportBySection.json'];
    st = awsReadJSON(stStructurePath);
end

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

%% Make report by library
libNames = s3GetAllLibs();

fprintf('\n');
fprintf('%3s || %7s | %5s %5s || %6s | %5s %5s\n','Lib','Healthy','Train','Test','Cancer','Train','Test');
fprintf('%s',repmat('-',1,52));
fprintf('\n');

for i=1:length(libNames)

    ii = cellfun(@(x)(strcmp(x,libNames{i})),st.libraryNames) & st.isUsableInML & st.isFreshHumanSample;
    
    if isGroupBySubject
        [~,~,uI] = unique(st.subjectNames(ii));
        uI([false;uI(2:end) == uI(1:(end-1))]) = false;
        uI = uI>0;
    else
        uI = ones(sum(ii),1,'logical');
    end
    
    h = st.isSampleHealthy(ii); h = h(uI);
    p = st.mlPhase(ii); p = p(uI);
    
    fprintf('%3s || %7d | %5d %5d || %6d | %5d %5d\n',...
        libNames{i},...
        sum(h==1),...
        sum(h==1 & p==-1), sum(h==1 & p==1),...
        sum(h==0),...
        sum(h==0 & p==-1), sum(h==0 & p==1)...
        );
end

% total
ii = st.isUsableInML & st.isFreshHumanSample;

if isGroupBySubject
    [~,~,uI] = unique(st.subjectNames(ii));
    uI([false;uI(2:end) == uI(1:(end-1))]) = false;
    uI = uI>0;
else
    uI = ones(sum(ii),1,'logical');
end

h = st.isSampleHealthy(ii); h = h(uI);
p = st.mlPhase(ii); p = p(uI);

fprintf('%s',repmat('-',1,52));
fprintf('\n');
fprintf('%3s || %7d | %5d %5d || %6d | %5d %5d\n',...
    'Tot',...
    sum(h==1),...
    sum(h==1 & p==-1), sum(h==1 & p==1),...
    sum(h==0),...
    sum(h==0 & p==-1), sum(h==0 & p==1)...
    );
