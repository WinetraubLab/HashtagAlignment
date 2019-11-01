function alignHistFM(slidePaths,histRawPaths,isDelayedUpload,tmpFolderSubjectFilePath)
%This function alignes histology slices with flourecence microscopy images
%INPUTS:
% - slidePaths - cell array of s3 path of the slides
% - histRawPaths - cell array of where the histology raw data is located,
%   can be local or on the cloud. If not specified, will assume histology
%   raw path is at [slidePaths 'Hist_Raw/']
% - isDelayedUpload - would you like to the delay the upload for later?
% - tmpDataFolderFilePath - temporary data folder to upload (mimics
%   subjectFolder). Make sure its empty if you use it

persistent isItFirstTimeRunningThisFunction
if isempty(isItFirstTimeRunningThisFunction)
    isItFirstTimeRunningThisFunction = true;
end

%% Input checks
if ~iscell(slidePaths)
    slidePaths = {slidePaths};
end
if exist('histRawPaths','var') && ~iscell(histRawPaths)
    histRawPaths = {histRawPaths};
elseif ~exist('histRawPaths','var')
    histRawPaths = cellfun(@(x)[x 'Hist_Raw/'],slidePaths,'UniformOutput',false);
end

if ~exist('tmpFolderSubjectFilePath','var')
    tmpFolderSubjectFilePath = 'TmpOutput\';
    
    %Make sure the folder is empty
    if exist(tmpFolderSubjectFilePath,'dir')
        rmdir(tmpFolderSubjectFilePath,'s');
    end
    mkdir(tmpFolderSubjectFilePath);
end

%% Provide instructions to user
if (isItFirstTimeRunningThisFunction)
   helpdlg({...
       'In the GUI, mark at least 4 points matching between histology and FM', ...
       'Make sure these are spaced around', ...
       'When done, close the GUI',...
       'If you need to flip the image just close the GUI without marking any points'...
       },'How to Use this Tool');
   isItFirstTimeRunningThisFunction = false; %You got this!
end

%% Main Job
awsSetCredentials();

if (isDelayedUpload)
    logFolderPath = awsModifyPathForCompetability([tmpFolderSubjectFilePath '\Log\04 Histology Preprocess\']);
    if ~exist(logFolderPath,'dir')
        mkdir(logFolderPath);
    end
else
    logFolderPath = awsModifyPathForCompetability([slidePaths{1} '../../Log/04 Histology Preprocess/']);
end

slideNames = cell(length(slidePaths),1);
for si=1:length(slideNames)
    [~,slideNames{si}] = fileparts([slidePaths{si}(1:end-1) '.a']);
end

for si = 1:length(slidePaths)
    %% Load Histology & FM images, JSON as well
    slideJson = awsReadJSON([slidePaths{si} 'SlideConfig.json']);
    a=yOCTFromTif([slidePaths{si} slideJson.brightFieldImagePath]);
    p = prctile(a(:),[2 98]);
    imFM = uint8((a-p(1))/diff(p)*255);
    ds=fileDatastore(awsModifyPathForCompetability([histRawPaths{si} 'Histo_*']),'ReadFcn',@imread);
    imHist=ds.read();
        
    %% Prompt user to select some points
    isHistImageFlipped = true;
    while true
        imHist1 = imHist;
        if(isHistImageFlipped)
            imHist1 = fliplr(imHist);
        end
        
        [selectedImHistPoints,selectedImFMPoints] = cpselect(...
            imHist1, ... Moved
            imFM, ... Bright field
            'Wait',true);
        
        if  isempty(selectedImHistPoints)
            %Try again with the flipped version
            isHistImageFlipped = ~isHistImageFlipped;
        else
            %We are done
            break;
        end
    end
    
    %Do the final flip if requried
    if(isHistImageFlipped)
        imHist = fliplr(imHist);
    end
    
    %Compute transfrom histo->FM
    tform = fitgeotrans(selectedImHistPoints,selectedImFMPoints,'nonreflectivesimilarity');
    FMCoordinates = imref2d(size(imFM)); %relate intrinsic and world coordinates
    imHistRegistered = imwarp(imHist,tform,'OutputView',FMCoordinates);
    
    %% Generate Log Figure of What We Have Done
    h=figure(1);
    set(h,'units','normalized','outerposition',[0 0 1 1]);
    subplot(2,2,1);
    imshow(imHist);
    hold on;
    plot(selectedImHistPoints(:,1),selectedImHistPoints(:,2),'dk','markerFaceColor','k');
    hold off;
    if (~isHistImageFlipped)
        title('Histology Image');
    else
        title('Histology Image, Flipped');
    end
    subplot(2,2,2);
    imshow(imFM);
    hold on;
    plot(selectedImFMPoints(:,1),selectedImFMPoints(:,2),'o','markerFaceColor','b');
    hold off;
    title('FM Image');
    
    subplot(2,2,[3 4]);
    imshowpair(rgb2gray(imHistRegistered),imFM)
    title('Registered Image');
    
    fileName = [slideNames{si} '_HistFMRegistration.png'];
    if (isDelayedUpload)
        saveas(h,[logFolderPath fileName]);
    else
        fp = [tmpFolderSubjectFilePath fileName];
        saveas(h,fp);
        awsCopyFileFolder(fp,logFolderPath);
        delete(fp);
    end
    
    %% Upload Hist Image to Cloud
    HEName = 'FM_HAndE.tif';
    disp('Saving Histology Image');
    if (isDelayedUpload)
        imwrite(imHistRegistered,[tmpFolderSubjectFilePath 'Slides\' slideNames{si} '\' HEName]);
    else
        fp = [tmpFolderSubjectFilePath HEName];
        imwrite(imHistRegistered,fp);
        awsCopyFileFolder(fp,slidePaths{si});
        delete(fp);
    end
    
    %% Update JSON
    slideJson.histologyImageFilePath = HEName;
    slideJson.FMHistologyAlignment.isHistologyFlipedLR = isHistImageFlipped;
    slideJson.FMHistologyAlignment.histology2FMTransform = tform.T;
    slideJson.FMHistologyAlignment.histologyImagePixelSizeBeforeAlignment_um = slideJson.FM.pixelSize_um*norm(tform.T(1:2,1));
    slideJson.FMHistologyAlignment.histologyImagePixelSizeAfterAlignment_um = slideJson.FM.pixelSize_um;
    awsWriteJSON(slideJson,[slidePaths{si} 'SlideConfig.json']); 
end