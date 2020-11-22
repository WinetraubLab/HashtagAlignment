% This script generates images for understanding the pathology utility and
% predictive power 

%% Inputs

modelName = 'paper v2'; % Part of the model name
isCorrectAspectRatio2To1 = true;

outputFolder = [pwd '\tmp\'];
scaleBar = 100; % Plot scale bar [um]

% Notice that total number of images to be rated by pathologist is
% (capSectionsTrain + capSectionsTest) * 2
capSectionsTrain = 14; % How many sections in train to cap
capSectionsTest = 35; % How many sections in test to cap

%% Download all images

[~, resultsPath] = s3GetPathToModelResults(modelName);

[modelToLoadFolder] = ...
    downlaodModelResultsImages(resultsPath,isCorrectAspectRatio2To1,outputFolder,scaleBar);

%% Gather meta data and st structure
[fpNames,fpToKeep] = awsls([outputFolder '/']);
fpToKeep = fpToKeep(:);
fp = fpToKeep;
fpNames = fpNames(:);

% Remove completely black patch or OCT image
ii = cellfun(@(x)(...
    contains(x,'black_') | ...
    contains(x,'real_A.png') ...
    ),fpToKeep);
fpToKeep(ii) = [];
fpNames(ii) = [];

%% Load ST data structure
stStructurePath = [modelToLoadFolder 'dataset_oct_histology/original_image_pairs/StatusReportBySection.json'];
if awsExist(stStructurePath,'file')
    % Dataset saved st as part of the data. Just load it from there
    st = awsReadJSON(stStructurePath);
else
    % Generate st based on current latest status
    warning('Couldn''t find st json file at "%s", so generating one based on lates library status which is not ideal for statistics',stStructurePath);
    
    % Figure out which libraries to load and load them
    libraryNames = fpNames;
    for i=1:length(libraryNames)
       nm = fpNames{i};
       ii=find(nm=='-',2,'first');
       nm(ii(1):end)=[];
       nm(1:find(nm=='_',1,'first')) = [];
       libraryNames{i} = nm;
    end
    libraryNames = unique(libraryNames);
    st = loadStatusReportByLibrary(libraryNames);
end

%% Filter out un needed sections

% Find sections with very best alignments
veryBestI = computeOverallSectionQuality(st) == 2 ...
    & st.isSampleHealthy==1; % Only get healthy subjects

% Pick sections from train and test sets
sectionsToUse = ...
    pickNRandomSections(st,capSectionsTrain,veryBestI & st.mlPhase == -1) | ...
    pickNRandomSections(st,capSectionsTest,veryBestI & st.mlPhase == 1) ;

% Which files are from these subjects
isVeryBestAlignment = findFilesInST(fpToKeep,st,sectionsToUse);

if sum(sectionsToUse)~=sum(isVeryBestAlignment)/2
    warning('Seems like very best slides acroding to st are different from actual sections loaded in dataset');
end

fpToKeep(~isVeryBestAlignment) = [];
fpNames(~isVeryBestAlignment) = [];

%% Copy best sections to a new temp folder, then copy back

% Make temporary directory
tmpDir = [pwd '\myTmp\'];
awsMkDir(tmpDir);

% Copy files
for i=1:length(fpToKeep)
    awsCopyFileFolder(fpToKeep{i},tmpDir);
end

% Remove original dir, and replace it with tmp dir
awsMkDir(outputFolder,true);
awsCopyFileFolder(tmpDir,outputFolder);
awsRmDir(tmpDir);

% Split to folders
ii = unique([0:100:length(fpToKeep) length(fpToKeep)]);
for i=1:(length(ii)-1)
    sd = sprintf('%s/%d/',outputFolder,i);
    awsMkDir(sd,true);
    for j=(ii(i)+1):ii(i+1)
        awsCopyFileFolder(fpToKeep{j},sd);
    end
end