% This script generates a status report of all the finish sections

libraryNames = {'LE'};

% What to lookfor when applying statistics
mode = 'isHistologyImageUploaded'; % Will only consider slides with histology uploaded for plot

%% Which are the finished sections
if ~exist('st','var')
    st = generateStatusReportByLibrary(libraryNames);
end

%% Re organize data
subjectPathsOut = st.subjectPahts; 
subjectNamesOut = st.subjectNames;
isGoodSections = st.(mode);
areaOfQualityData_mm2 = st.areaOfQualityData_mm2;

subjectPathsOut = subjectPathsOut(isGoodSections);
subjectNamesOut = subjectNamesOut(isGoodSections);
areaOfQualityData_mm2 = areaOfQualityData_mm2(isGoodSections);

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
    
    % Save data
    if strcmpi(json.samePatientAsSampleWithId,'New Patient')
        dataPerSubject{i} = dt;
    else
        % Add this data to another subject
        
        % Find which subject
        ii = find(cellfun( @(x)(strcmpi(x,json.samePatientAsSampleWithId)), ...
            uniqueSubjectNames));
        if length(ii) ~= 1
            error('Couldnt figure out what patient to associate it');
        end
        dataPerSubject{ii}.numberOfSamples  = ...
            dataPerSubject{ii}.numberOfSamples + ...
            dt.numberOfSamples;
        
        % Remove this subject
        isToDeleteUniqueSubject(i) = true; continue;
    end
end

dataPerSubject(isToDeleteUniqueSubject) = [];

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
numberOfSections = cellfun(@(x)(x.numberOfSamples),dataPerSubject);
gender = cellfun(@(x)(x.gender),dataPerSubject);
age =  cellfun(@(x)(x.age.*ones(1,x.numberOfSamples)),dataPerSubject,'UniformOutput',false);
age = [age{:}];
fitzpatrickSkinType =  cellfun(@(x)(x.fitzpatrickSkinType.*ones(1,x.numberOfSamples)),dataPerSubject,'UniformOutput',false);
fitzpatrickSkinType = [fitzpatrickSkinType{:}];
library = cellfun(@(x)((x.sampleId(2)-'A').*ones(1,x.numberOfSamples)),dataPerSubject,'UniformOutput',false);
library = [library{:}];

if strcmpi(prefix,'sections')
    titlePrefix = 'Sections by Patient''s';
else
    titlePrefix = [prefix ' by'];
end

subplot(2,3,[1 4]);
[regionNames, regionNumberOfDataPoints] = ...
    drawStatisticsOnBody(sampleLocations,numberOfSections);
title(sprintf('Total %s: %d\nDot location doesn''t reflect laterality',prefix, sum(numberOfSections)));

subplot(2,3,2);
bar([ ...
    sum((gender==1).*numberOfSections) ...
    sum((gender==-1).*numberOfSections) ...
    ...sum((gender==0).*numberOfSections) ...
    ],'FaceAlpha',0.6);
title ([titlePrefix ' Gender']);
ylabel(['# of ' prefix]);
grid on;
xticklabels({'Male' 'Female'});

subplot(2,3,3);
histogram(age,10,'FaceAlpha',0.6);
title([titlePrefix ' Age']);
ylabel(['# of ' prefix]);
xlabel('years');
grid on;

subplot(2,3,5);
histogram(fitzpatrickSkinType,(1:6)-0.5,'FaceAlpha',0.6);
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