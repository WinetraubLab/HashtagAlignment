% This script generates images for understanding the pathology utility and
% predictive power 

%% Inputs

modelName = 'Yonatan'; % Part of the model name
isCorrectAspectRatio2To1 = true;

outputFolder = [pwd '\tmp\'];
scaleBar = 100; % Plot scale bar [um]

% Notice that total number of images to be rated by pathologist is
% (capSectionsTrain + capSectionsTest) * 2
capSectionsTrain = 14; % How many sections in train to cap
capSectionsTest = 35; % How many sections in test to cap

%% Download all images
[~, modelToLoadFolder] = ...
    downlaodModelResultsImages(modelName,isCorrectAspectRatio2To1,outputFolder,scaleBar);

%% Gather meta data and st structure
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

%% Filter out un needed sections
fpToKeepIndex = ones(size(fpToKeep),'logical');

% Find sections with very best alignments
verBest1 = computeOverallSectionQuality(st) == 2;
isVeryBestAlignment = whichFilesContainTheseSections(fpToKeep, st, verBest1);

% Remove cancer samples
ii = cellfun(@(x)(contains(x,'LGC-')),fpToKeep);
fpToKeepIndex(ii) = false;

% Remove OCT images, we are only interested in real and fake histology
ii = cellfun(@(x)(contains(x,'real_A.png')),fpToKeep);
fpToKeepIndex(ii) = false;

% Print statistics
fprintf('STATISTICS (excluding cancer):\n Training Set: %d Sections\n  Testing Set: %d Sections\n', ...
    sum(cellfun(@(x)(contains(x,'train')),fpToKeep(fpToKeepIndex)))/2, ...
    sum(cellfun(@(x)(contains(x,'test')),fpToKeep(fpToKeepIndex)))/2);
fprintf(' Best aligned sections out of overall sections: %.1f%%\n',sum(isVeryBestAlignment)/length(isVeryBestAlignment)*100);

% Remove not very best alignment
fpToKeepIndex(~isVeryBestAlignment) = false;

fpToKeep(~fpToKeepIndex) = [];
fpNames(~fpToKeepIndex) = [];

%% Handle caps
fpToKeepIndex = zeros(size(fpToKeep),'logical');

fpToKeepIndex = fpToKeepIndex | PickWhichFilesToKeep(fpNames,'train',capSectionsTrain);
fpToKeepIndex = fpToKeepIndex | PickWhichFilesToKeep(fpNames,'test',capSectionsTest);

fpToKeep(~fpToKeepIndex) = [];
fpNames(~fpToKeepIndex) = [];
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

function isFileInSt = whichFilesContainTheseSections(filePaths,st,stIToFindInFiles)
% Auxilary function returning filePaths index which are of sections to
% search for
% INPUTS:
%   filePaths - cell array of filepaths to match
%   st - st structure of all sections
%   stIToFindInFiles - which of st to search for in the files? Can be
%   indexes or bollean array.
% OUTPUTS:
%   isFileInSt - logic array, for each file path, is it in the file to
%   search or out?

if (islogical(stIToFindInFiles))
    stIToFindInFiles = find(stIToFindInFiles);
end

subjectNamesToSearchFor = cell(length(stIToFindInFiles),1);
for isFileInSt=1:length(subjectNamesToSearchFor)
    subjectNamesToSearchFor{isFileInSt} = [st.subjectNames{stIToFindInFiles(isFileInSt)} '-' st.sectionNames{stIToFindInFiles(isFileInSt)}];
end

% Remove sections that don't have the very best alignment
isFileInSt = zeros(size(filePaths),'logical');
for i=1:length(isFileInSt)
    isFileInSt(i) = any(cellfun(@(x)(contains(filePaths{i},x)),subjectNamesToSearchFor));
end

end

function fpToKeepIndex = PickWhichFilesToKeep(fpNames,phase,cap)
% phase can be 'train' or 'test'
% cap is the maximum number of samples from the phase

% Find subjects for each fp
fpSubjects = cell(size(fpNames));
for i=1:length(fpSubjects)
    tmp = fpNames{i};
    fpSubjects{i} = tmp(1:(strfind(tmp,'-Slide')-1));
end

fpToKeepIndex = zeros(size(fpNames),'logical');

%% Phase #1 - split real & fake, and figure out which files are from the rigth phase
% Get only the files that are real & fake
realBFilesIndex = find( ...
    cellfun(@(x)(contains(x,'_real_B.')),fpNames) & ...
    cellfun(@(x)(contains(x,[phase '_'])),fpNames));
fakeBFilesIndex = find (...
    cellfun(@(x)(contains(x,'_fake_B.')),fpNames) & ...
    cellfun(@(x)(contains(x,[phase '_'])),fpNames));

%% Step #2 select which files to keep
% Randomize to mix a bit
p = randperm(length(realBFilesIndex));
realBFilesIndex = realBFilesIndex(p);
fakeBFilesIndex = fakeBFilesIndex(p);

% Trim down how many files needed to get rid off of to reach cap
n = length(fakeBFilesIndex)-cap;
for i=1:n
    % Compute which subjects has maximal number of sections
    [u, ~, ui] = unique(fpSubjects(realBFilesIndex),'stable');
    ul = zeros(size(u));
    for j=1:length(u)
        ul(j) = sum(ui == j);
    end
    
    % Find subject with max number of sections
    s = u{find(ul == max(ul),1,'first')};
    
    % Remove one section from that subject
    iToRemove = find(cellfun(@(x)(strcmp(s,x)),fpSubjects(realBFilesIndex)),1,'first');
    realBFilesIndex(iToRemove) = [];
    fakeBFilesIndex(iToRemove) = [];
end

%% Step #3: Overall what to keep
fpToKeepIndex(realBFilesIndex) = true;
fpToKeepIndex(fakeBFilesIndex) = true;

end