% This script generates a status report of all the finish sections

datasetTag = '2020-11-10'; % Which dataset tag to load? Will load the latest unless specific date is writen in tag

% What to lookfor when applying statistics
%mode = 'isHistologyImageUploaded'; % Will only consider slides with histology uploaded for plot
mode = 'isUsableInML'; % Most strict consideration

% Mode can be 1,2,3
%   1 - concatinate all train and test sets to one set and plot it on the
%       body figure
%   2 - plot only train set
%   4 - plot only test set without cancer
%   3 - plot train and test but in different colors (blue is train, red is
%       test)
plotAreasMode = 2;

% When set, will devide up to training and testing, set to NaN to ignore
% deviding, set to {} to use default split
filesInTestingSet = NaN;

%% Which are the finished sections

[datasetPath, datasetName] = s3GetPathToLatestDataset('10x',datasetTag);
stStructurePath = [datasetPath '/original_image_pairs/StatusReportBySection.json'];
st = awsReadJSON(stStructurePath);

% For backward compatibility, can remove this section in the future.
if ~isfield(st,'isFreshHumanSample')
    st.isFreshHumanSample = ...
        ~cellfun(@(x)(contains(x,'LGM') | contains(x,'LFM')),st.subjectNames);
end

% Read current report
%libraryNames = s3GetAllLibs();
%st = loadStatusReportByLibrary(libraryNames);

%% Re organize data
subjectPathsOut = st.subjectPahts; 
subjectNamesOut = st.subjectNames;
isGoodSections = st.(mode) & st.isFreshHumanSample & st.isSampleHealthy;
areaOfQualityData_mm2 = st.areaOfQualityData_mm2;
subjetPhase = st.mlPhase;

subjectPathsOut = subjectPathsOut(isGoodSections);
subjectNamesOut = subjectNamesOut(isGoodSections);
areaOfQualityData_mm2 = areaOfQualityData_mm2(isGoodSections);
subjetPhase = subjetPhase(isGoodSections);

uniqueSubjectPaths = unique(subjectPathsOut);
uniqueSubjectNames = cellfun(@s3GetSubjectName,uniqueSubjectPaths,'UniformOutput',false);

%% Get Data Per Subject
dataPerSubject = cell(size(uniqueSubjectNames));
isToDeleteUniqueSubject = zeros(size(dataPerSubject),'logical');

for i=1:length(uniqueSubjectNames)
    json = awsReadJSON([uniqueSubjectPaths{i} '/Subject.json']);
    
    if json.isFreshHumanSample ~= 1
        % This subject is no good.
        isToDeleteUniqueSubject(i) = true; continue;
    end
    
    % Get data
    clear dt;
    dt.sampleId = json.sampleId;
    dt.age = str2double(json.age);
    if strcmpi(json.gender,'male')
        dt.gender = 1;
    elseif strcmpi(json.gender,'female')
        dt.gender = -1;
    else
        dt.gender = 0; % Unknown / other
    end
    dt.fitzpatrickSkinType  = str2double(json.fitzpatrickSkinType);
    dt.sampleLocation = json.sampleLocation;
    samplesInThisSubject = cellfun(@(x)(strcmpi(x,uniqueSubjectNames{i})),...
                                        subjectNamesOut);
    dt.numberOfSamples = sum(samplesInThisSubject);
    dt.areaOfQualityData_mm2 = nansum(areaOfQualityData_mm2(samplesInThisSubject));
    dt.subjetPhase = nanmedian(subjetPhase(samplesInThisSubject));
    
    % Save data
    if strcmpi(json.samePatientAsSampleWithId,'New Patient')
        dataPerSubject{i} = dt;
    else
        % Add this data to another subject
        
        % Find which subject
        ii = find(cellfun( @(x)(strcmpi(x,json.samePatientAsSampleWithId)), ...
            uniqueSubjectNames));
        if isempty(ii)
            warning('Patient %s seems to be the same as sample %s, but couldn''t find the latter, does it have no good samples? Anyways appling this sample as %s', json.sampleId, json.samePatientAsSampleWithId, json.samePatientAsSampleWithId);
            dataPerSubject{i} = dt;
            uniqueSubjectNames{i} = json.samePatientAsSampleWithId;
        elseif length(ii) > 1
            error('This shouldn''t happen');
        else
            dataPerSubject{ii}.numberOfSamples  = ...
                dataPerSubject{ii}.numberOfSamples + ...
                dt.numberOfSamples;

            % Remove this subject
            isToDeleteUniqueSubject(i) = true; continue;
        end
    end
end

dataPerSubject(isToDeleteUniqueSubject) = [];

%% Split to train & test
isTraining = cellfun(@(x)(x.subjetPhase),dataPerSubject)==-1;

% Go over all samples, modify
iiToDelete = [];
for i=1:length(dataPerSubject)
    switch(plotAreasMode)
        case 1
            dataPerSubject{i}.isTraining = true;
        case 2
            % Plot only train set
            if isTraining(i)
                dataPerSubject{i}.isTraining = true;
            else
                iiToDelete = [iiToDelete i];
            end
        case 3
            dataPerSubject{i}.isTraining = isTraining(i);
            
        case 4
            % Plot only test set
            if ~isTraining(i) && ...
                dataPerSubject{i}.sampleId(3) ~= 'C' % Cancer, for example: LGC
                dataPerSubject{i}.isTraining = true;
            else
                iiToDelete = [iiToDelete i];
            end
    end
end
dataPerSubject(iiToDelete) = [];

% Print which subject are included
%cellfun(@(x)(x.sampleId),dataPerSubject,'UniformOutput',false)

%% Draw - Sections Statistics
fig1 = figure(1);
set(fig1,'units','normalized','outerposition',[0 0 1 1]);
myDraw(dataPerSubject,'Sections');
saveas(fig1,'Stats_NumberOfSections.png');

%% Draw - Patient Statistics
dataPerSubject1 = dataPerSubject;
for i=1:length(dataPerSubject1)
    dataPerSubject1{i}.numberOfSamples = 1;
end

fig1 = figure(1);
set(fig1,'units','normalized','outerposition',[0 0 1 1]);
myDraw(dataPerSubject1,'Patients');
saveas(fig1,'Stats_NumberOfPatient.png');

%% Helper function to do the actual drawing
function myDraw(dataPerSubject,prefix)

sampleLocations = cellfun(@(x)(x.sampleLocation),dataPerSubject,'UniformOutput',false);
isSampleInTrainingSet = logical(cell2mat(cellfun(@(x)(x.isTraining),dataPerSubject,'UniformOutput',false)));
isSectionInTrainingSet = cellfun(@(x)(x.isTraining*ones(1,x.numberOfSamples)),dataPerSubject,'UniformOutput',false);
isSectionInTrainingSet = logical([isSectionInTrainingSet{:}]);
numberOfSections = cellfun(@(x)(x.numberOfSamples),dataPerSubject);
gender = cellfun(@(x)(x.gender),dataPerSubject);
age =  cellfun(@(x)(x.age.*ones(1,x.numberOfSamples)),dataPerSubject,'UniformOutput',false);
age = [age{:}];
fitzpatrickSkinType =  cellfun(@(x)(x.fitzpatrickSkinType.*ones(1,x.numberOfSamples)),dataPerSubject,'UniformOutput',false);
fitzpatrickSkinType = [fitzpatrickSkinType{:}];
library = cellfun(@(x)((x.sampleId(2)-'A').*ones(1,x.numberOfSamples)),dataPerSubject,'UniformOutput',false);
library = [library{:}];
areaOfQualityData_mm2 = cellfun(@(x)(x.areaOfQualityData_mm2),dataPerSubject);

if strcmpi(prefix,'sections')
    titlePrefix = 'Sections by Patient''s';
else
    titlePrefix = [prefix ' by'];
end

subplot(2,3,[1 4]);
[regionNames, regionNumberOfDataPoints] = ...
    drawStatisticsOnBody(...
        sampleLocations(isSampleInTrainingSet), ...
        numberOfSections(isSampleInTrainingSet), ...
        sampleLocations(~isSampleInTrainingSet), ...
        numberOfSections(~isSampleInTrainingSet) ...
        );
title(sprintf('Total %s: %d\n Average Area: %.2f mm^2',...
    prefix, sum(numberOfSections(:)), ...
    sum(areaOfQualityData_mm2(isSampleInTrainingSet))/sum(numberOfSections(isSampleInTrainingSet))));
subplot(2,3,2);
bar([ ...
    sum((gender==1).*numberOfSections.*isSampleInTrainingSet) ...
    sum((gender==-1).*numberOfSections.*isSampleInTrainingSet) ...
    ...sum((gender==0).*numberOfSections) ...
    ],'FaceAlpha',0.6);
title ([titlePrefix ' Gender']);
ylabel(['# of ' prefix]);
grid on;
xticklabels({'Male' 'Female'});

subplot(2,3,3);
histogram(age(isSectionInTrainingSet),10,'FaceAlpha',0.6);
title([titlePrefix ' Age']);
ylabel(['# of ' prefix]);
xlabel('Years');
grid on;

subplot(2,3,5);
histogram(fitzpatrickSkinType(isSectionInTrainingSet),(1:6)-0.5,'FaceAlpha',0.6);
title([titlePrefix ' Fitzpatrick Skin Type']);
ylabel(['# of ' prefix]);
xlabel('Skin Type');
xticks([1 2 3 4 5]);
grid on;

subplot(2,3,6);
nRegions = 6;
bar(0:(nRegions-1),regionNumberOfDataPoints(1:nRegions), ...
    'FaceAlpha',0.6);
title([prefix ' by Region']);
ylabel(['# of ' prefix]);
xticks(0:(nRegions-1));
xticklabels(regionNames(1:nRegions));
grid on;

end