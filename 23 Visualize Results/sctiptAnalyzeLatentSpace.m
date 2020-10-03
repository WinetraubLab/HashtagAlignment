% This script analyzes images latent space

%% Inputs
datasetBaseDirectory = s3SubjectPath('','_MLModels');
baseMLFolder = [datasetBaseDirectory '2020-08-15 10x Yonatan Pix2Pix'];

% Path to the specific model results
modelName = 'pix2pix'; % 'pix2pix_2to1_ratio','pix2pix_256px256px'
testImagesPath = [baseMLFolder '/results/' modelName '/test_latest/images/'];
trainImagesPath = [baseMLFolder '/results/' modelName '/train_latest/images/'];
latentPath = [baseMLFolder '/results/' modelName '/feats/center/'];

isCorrectAspectRatio2To1 = true; % Set to true if aspect ratio needs correction to 2 to 1

%% Load all latent features
ds = fileDatastore([latentPath 'L*.mat'],'ReadFcn',@load);
featuresDS = ds.readall();
features = cellfun(@(x)(x.feats(:)'),featuresDS(:),'UniformOutput',false);
features = cell2mat(features);
samplesName = cell(size(features,1),1);
subjectsName = samplesName;
for i=1:length(samplesName)
    [~,samplesName{i}] = fileparts(ds.Files{i});
    subjectsName{i} = samplesName{i}(1:5);
end

%% Read Json, seperate to train test
json = awsReadJSON([baseMLFolder '/dataset_oct_histology/original_image_pairs/DatasetConfig.json']);

isTestingSample = any(cell2mat(...
    cellfun(@(x)(contains(subjectsName,x)),json.filesInTestingSet','UniformOutput',false)),2);

% Sort subjects and features training first
[~,i] = sort(isTestingSample);
features = features(i,:);
samplesName = samplesName(i);
subjectsName = subjectsName(i);
isTestingSample = isTestingSample(i);

firstTestingSampleI = find(isTestingSample,1,'first');

%% Compute First Sample In Subject
subjectsNameUnique = unique(subjectsName);
firstSampleOfSubjectI = zeros(size(subjectsNameUnique));
for i=1:length(subjectsNameUnique)
    firstSampleOfSubjectI(i) = ...
        find(cellfun(@(x)(strcmp(x,subjectsNameUnique{i})),subjectsName),1,'first');
end

[~,i] = sort(firstSampleOfSubjectI);
firstSampleOfSubjectI = firstSampleOfSubjectI(i);
subjectsNameUnique = subjectsNameUnique(i);
isTestingSubject = firstSampleOfSubjectI>=firstTestingSampleI;

%% Compute Feature Matrix
D = pdist(features);
Ds = squareform(D); %L2 distance

%% Some statistics

% Within subject correlation
withinSubjectCorrelationTrain = [];
withinSubjectCorrelationTest = [];
for i=1:length(firstSampleOfSubjectI)
    iStart = firstSampleOfSubjectI(i);
    if i==length(firstSampleOfSubjectI)
        iEnd = length(subjectsName);
    else
        iEnd = firstSampleOfSubjectI(i+1)-1;
    end
    
    tmp = Ds(iStart:iEnd,iStart:iEnd);
    tmp = tmp + diag(NaN*ones(1,size(tmp,2)));
    tmp(isnan(tmp)) = [];
    if(~isTestingSubject(i))
        withinSubjectCorrelationTrain = [withinSubjectCorrelationTrain; tmp(:)];
    else
        withinSubjectCorrelationTest = [withinSubjectCorrelationTest; tmp(:)];
    end
    
end

figure(2);
histogram(withinSubjectCorrelationTrain/median(withinSubjectCorrelationTrain));
hold on;
histogram(withinSubjectCorrelationTest/median(withinSubjectCorrelationTrain));
hold off;
title(sprintf('Within Subject Norm Distances\nTrain Median: %.1f Test Median: %.1f',1,...
    median(withinSubjectCorrelationTest)/median(withinSubjectCorrelationTrain)));
xlabel('Normalized Diatances');
grid on;
legend('Train','Test');

% Normalize distances
Ds = Ds/median(withinSubjectCorrelationTrain);

% Compute subject distances
Dss = zeros(length(subjectsNameUnique));
for i=1:size(Dss,1)
    for j=i:size(Dss,2)
        ii = cellfun(@(x)(strcmp(x,subjectsNameUnique(i))),subjectsName);
        jj = cellfun(@(x)(strcmp(x,subjectsNameUnique(j))),subjectsName);
        tmp = Ds(ii,jj);
        Dss(i,j) = prctile(tmp(:),20);
        Dss(j,i) = Dss(i,j);
    end
end

%% Plot Status
% Draw feature space
figure(1);
imagesc(Ds);
hold on;
plot([1 length(subjectsName)],firstTestingSampleI*[1 1],'k','LineWidth',2);
plot(firstTestingSampleI*[1 1],[1 length(subjectsName)],'k','LineWidth',2);
hold off;
plotSujbectLines(firstSampleOfSubjectI,subjectsNameUnique,[1 length(subjectsName)],true)
plotSujbectLines(firstSampleOfSubjectI,subjectsNameUnique,[1 length(subjectsName)],false)
title('L2 Distances Normalized by In Subject Distances');
colorbar

%% For each test set, find the 3 subjects with the closest distance

for subjectI=1:length(subjectsNameUnique)

    if (~isTestingSubject(subjectI))
        continue;
    end

    % Find distances to this subject
    d = Dss(subjectI,~isTestingSubject);
    [~,ii] = sort(d);

    figure(100+subjectI);
    if isTestingSubject(subjectI)
        refPath = [testImagesPath samplesName{firstSampleOfSubjectI(subjectI)}];
    else
        refPath = [trainImagesPath samplesName{firstSampleOfSubjectI(subjectI)}];
    end
    subplot(2,3,1);
    ds = fileDatastore([refPath '_real_A*'],'ReadFcn',@imread);
    imshow(ds.read());
    title(sprintf('%s OCT',subjectsNameUnique{subjectI}));
    ylabel('Test Sample');

    subplot(2,3,2);
    ds = fileDatastore([refPath '_fake_B*'],'ReadFcn',@imread);
    imshow(ds.read());
    title(sprintf('%s Generated Histology',subjectsNameUnique{subjectI}));

    subplot(2,3,3);
    ds = fileDatastore([refPath '_real_B*'],'ReadFcn',@imread);
    imshow(ds.read());
    title(sprintf('%s Real Histology',subjectsNameUnique{subjectI}));

    % Shortest diatnace 
    for i=1:3
        % Get one image associated with subject
        ds = fileDatastore([trainImagesPath samplesName{firstSampleOfSubjectI(ii(i))} '_real_B*'],'ReadFcn',@imread);
        subplot(2,3,i+3);
        imshow(ds.read());
        
        title(sprintf('%s, Normalized Dist: %.2f',subjectsNameUnique{ii(i)},d(ii(i))));
        if (i==1)
            ylabel('Closest Members of Training Set');
        end
    end
end

%% Auxilary function
function plotSujbectLines(firstSampleOfSubjectI,subjectsNameUnique,plotStartEnd,isX)
% isX - if false will do y axis
hold on;
for i=1:length(firstSampleOfSubjectI)
    if isX
        plot(firstSampleOfSubjectI(i)*[1 1],plotStartEnd,':k');
    else
        plot(plotStartEnd,firstSampleOfSubjectI(i)*[1 1],':k');
    end
end
hold off;

if (isX)
    xticks(firstSampleOfSubjectI);
    xticklabels(subjectsNameUnique);
    xtickangle(90);
else
    yticks(firstSampleOfSubjectI);
    yticklabels(subjectsNameUnique);
end
end


    