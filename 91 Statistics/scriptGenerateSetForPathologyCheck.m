% This script generates images for understanding the pathology utility and
% predictive power 

%% Inputs

modelName = 'Yonatan'; % Part of the model name
isCorrectAspectRatio2To1 = true;

outputFolder = [pwd '\tmp\'];
scaleBar = 100; % Plot scale bar [um]

%% Download all images
[~, modelToLoadFolder] = ...
    downlaodModelResultsImages(modelName,isCorrectAspectRatio2To1,outputFolder,scaleBar);

%% Gather meta data, decide which sections to keep 
[fpNames,fpToKeep] = awsls([outputFolder '/']);
fpToKeep = fpToKeep(:);
fp = fpToKeep;
fpNames = fpNames(:);

% Remove completely black patch
ii = cellfun(@(x)(contains(x,'black_')),fpToKeep);
fpToKeep(ii) = [];
fpNames(ii) = [];

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

% Find sections with very best alignments
goodI = find(getSectionsWithBestAlignment(st));
veryBestSectionsNames = cell(length(goodI),1);
for i=1:length(veryBestSectionsNames)
    veryBestSectionsNames{i} = [st.subjectNames{goodI(i)} '-' st.sectionNames{goodI(i)}];
end

% Remove sections that don't have the very best alignment
isVeryBestAlignment = zeros(size(fpToKeep));
for i=1:length(isVeryBestAlignment)
    isVeryBestAlignment(i) = any(cellfun(@(x)(contains(fpToKeep{i},x)),veryBestSectionsNames));
end
%fpToKeep(~isVeryBestAlignment) = [];
%fpNames(~isVeryBestAlignment) = [];

% Remove cancer samples
ii = cellfun(@(x)(contains(x,'LGC-')),fpToKeep);
fpToKeep(ii) = [];
fpNames(ii) = [];

% Print statistics
fprintf('STATISTICS (excluding cancer):\n Training Set: %d Sections\n  Testing Set: %d Sections\n', ...
    sum(cellfun(@(x)(contains(x,'train')),fpToKeep))/3, ...
    sum(cellfun(@(x)(contains(x,'test')),fpToKeep))/3);
fprintf(' Best aligned sections out of overall sections: %.1f%%\n',sum(isVeryBestAlignment)/length(isVeryBestAlignment)*100);

% Remove OCT files
ii = cellfun(@(x)(contains(x,'real_A.png')),fpToKeep);
fpToKeep(ii) = [];
fpNames(ii) = [];

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
ii = unique([0:90:length(fpToKeep) length(fpToKeep)]);
for i=1:(length(ii)-1)
    sd = sprintf('%s/%d/',outputFolder,i);
    awsMkDir(sd,true);
    for j=(ii(i)+1):ii(i+1)
        awsCopyFileFolder(fpToKeep{j},sd);
    end
end
