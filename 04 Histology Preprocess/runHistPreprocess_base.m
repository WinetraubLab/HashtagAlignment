function runHistPreprocess_base(runAutomatic)

%This function runs all the preprocessing steps of histology. 
%1) Importing to aws
%2) Aligning H&E slides with Flourecense microscope images
%This script is run as stand alone and would propt user with all required
%inputs

%No need to change any parameter, just run
tAll = tic;
%% Prepare Environment
close all
awsSetCredentials();

%This is a temporary folder for saving data for upload, make sure you have
%write permisions. This folder mimics subject folder
tmpFolderSubjectFilePath = [tempname([ pwd '\']) '\']; 

%Make sure tmpFolderRoot is empty
disp('Creating a temporary folder to save output');
if exist(tmpFolderSubjectFilePath,'dir')
    rmdir(tmpFolderSubjectFilePath,'s');
end
mkdir(tmpFolderSubjectFilePath);

%Prompt user to select a file
%[tmp1,tmp2] = uigetfile('.svs','Select File');
[tmp1,tmp2] = uigetfile('\\171.65.17.174\e\Caroline\LE-Histology Scans\*.svs','Select File');
histologyFP = [tmp2 tmp1];
%histologyFP = 'E:\myslides\1000418.svs'; %File path to .svs file

if ~exist(histologyFP,'file')
    error('File %s, does not exist',histologyFP);
end

%% Figure out slide information

%Open slide info tiff
info=imfinfo(histologyFP);
if length(info) == 7
    slideInfoIm  = imread(histologyFP,'Index',6);
else
    slideInfoIm  = imread(histologyFP,'Index',5);    
end
    
imshow(slideInfoIm);
title('Do you see slide information?');
[out] = inputdlg({'Library:','Subject Number:','Slide Number:'},'Slide Info',[1 35],{'LC','01','01'});
close;

if isempty(out)
    disp('Aborting');
    return;
end

%Make sure propare numbering
out{2} = sprintf('%02d',str2double(out{2}));
out{3} = sprintf('%02d',str2double(out{3}));

%Generate subject name and path
subjectFolder = s3SubjectPath(out{2},out{1});
[~,subjectName] = fileparts([subjectFolder(1:end-1) '.a']);

%Slides & sections names
fd = fileDatastore(sprintf('%sSlides/Slide%s*',subjectFolder,out{3}),'ReadFcn',@(x)(x),'FileExtensions','.json');
fld = cellfun(@fileparts,fd.Files,'UniformOutput',false); %Get folders 
fld = unique(fld);
slideSections = cellfun(@(x)(strrep(x,sprintf('%sSlides/',subjectFolder),'')),fld,'UniformOutput',false);

%% Choose which slides to upload
if runAutomatic == false
    [indx,~] = listdlg('PromptString',{'Select one or more files to run.',...
                        'Hold shift to select multiple.',''},...
                        'ListString',slideSections);
    slideSections = slideSections([indx],:);
end
%% Import & Crop
close all;
outStatus = histSVSImport(histologyFP,subjectFolder,slideSections,true,tmpFolderSubjectFilePath);
if ~outStatus
    return;
end

%% Align Histolgoy with OCT
close all;
%Generate Input
slideS3Path = cell(length(slideSections),1);
histLocalPath = cell(length(slideSections),1);
for i=1:length(slideS3Path)
    slideS3Path{i} = awsModifyPathForCompetability([subjectFolder 'Slides/' slideSections{i} '/']);
    histLocalPath{i} = awsModifyPathForCompetability([tmpFolderSubjectFilePath 'Slides/' slideSections{i} '/Hist_Raw/']);
end
alignHistFM(slideS3Path,histLocalPath,true,tmpFolderSubjectFilePath,runAutomatic);

%% Upload 
disp('Uploading Everything To The Cloud');
awsCopyFileFolder(tmpFolderSubjectFilePath,subjectFolder);

%% Cleanup
rmdir(tmpFolderSubjectFilePath,'s'); %Cleanup
close all;
disp('Done');

t = toc(tAll);
fprintf('\nFYI, preprocessing of this slide took you %.1f minutes start to finish\n',t/60);

%% Ask user one more time, did alignment succeeded?
for i=1:length(slideS3Path)
    % Read Json from file
    slideJson = awsReadJSON([slideS3Path{i} '/SlideConfig.json']);
    if ~isfield(slideJson,'FMHistologyAlignment')
        continue; % Wasn't aligned
    end
    
    % Present registration overview to user
    [~,slideName] = fileparts([slideS3Path{i}(1:end-1) '.a']);
    logFolderPath = awsModifyPathForCompetability([slideS3Path{i} '../../Log/04 Histology Preprocess/']);
    fileName = [logFolderPath slideName '_HistFMRegistration.png'];
    ds = fileDatastore(fileName,'ReadFcn',@imread);
    im = ds.read;
    imshow(im);
    
    % Ask 'the' question
    answer = questdlg('Did Histology Aligned to Brightfield?','Question','Yes','No','No');
    if strcmp(answer,'Yes')
        slideJson.FMHistologyAlignment.wasAlignmentSuccessful = true;
    else
        slideJson.FMHistologyAlignment.wasAlignmentSuccessful = false;
    end
    
    % Upload Json
    awsWriteJSON(slideJson,[slideS3Path{i} '/SlideConfig.json']);
end
        
        
        