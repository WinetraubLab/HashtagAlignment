function outStatus = histSVSImport(histologyFP,subjectFolder,slideSections,isDelayedUpload,tmpFolderSubjectFilePath)
%This function imports H&E Images from SVS format
%INPUTS:
% - histologyFP - file path pointing to .svs
% - subjectFolder - pointer to the cloud where the subject is
% - slideSections - what slides and sections to upload (cell array)
% - isDelayedUpload - would you like to the delay the upload for later?
% - tmpDataFolderFilePath - temporary data folder to upload (mimics
%   subjectFolder). Make sure its empty if you use it
%EXAMPLE:
% histSVSImport('C:\hist.svs','s3://LC/LC-01/',{'Slide01_Section01','Slide01_Section02'});
outStatus = false;

if ~exist('isDelayedUpload','var')
    isDelayedUpload = false;
end

if ~exist('tmpFolderSubjectFilePath','var')
    tmpFolderSubjectFilePath = 'TmpOutput\';
    
    %Make sure the folder is empty
    if exist(tmpFolderSubjectFilePath,'dir')
        rmdir(tmpFolderSubjectFilePath,'s');
    end
    mkdir(tmpFolderSubjectFilePath);
end

[~,subjectName] = fileparts([subjectFolder(1:end-1) '.a']);
%% Ask user to mark all sections

%Load High Level Data
info=imfinfo(histologyFP);
lowResSlideIm=imread(histologyFP,'Index',2);
% slide info vs whole slide depends on how many slides in the stack.
if length(info) == 7
    slideInfoIm  =imread(histologyFP,'Index',6);
    wholeSlideIm =imread(histologyFP,'Index',7);
else
    slideInfoIm  =imread(histologyFP,'Index',5);
    wholeSlideIm =imread(histologyFP,'Index',6);
end
%Make the main figure
figure(1);
subplot(3,3,1);
imshow(slideInfoIm);
subplot(3,3,[2 3]);
imshow(wholeSlideIm);
ax =  subplot(3,3,4:9);
imshow(lowResSlideIm);
s = size(lowResSlideIm); s = s(1:2);

rois = zeros(length(slideSections),4);
angles = zeros(length(slideSections),1);
for si=1:length(slideSections)
    figure(1);
    subplot(ax);
    title([subjectName ', Please select ' strrep(slideSections{si},'_',' ') ' Press Space When Done']);
    if (~exist('roi','var'))
        h=imrect(ax,fliplr([s s]).*[0.25 0.25 0.5 0.5]);
    else
        %Use previuse ROI size
        h=imrect(ax,[s(2) s(1) 0 0].*[0.25 0.25 0 0] + [0 0 roi(3:4)]);
    end
    while(waitforbuttonpress()==0) %Wait for button press
    end
    
    roi=getPosition(h);
    rois(si,:) = roi;
    
    delete(h);

    %% Let user define rotaion
    l = 4; %Layer to load the small image
    Rows=[roi(2) roi(2)+roi(4)]*info(l).Height/s(1);
    Cols=[roi(1) roi(1)+roi(3)]*info(l).Width /s(2);
    imSmall = imread(histologyFP,'Index',l,'PixelRegion',{Rows,Cols});
    isDone = false;
    if ~exist('rot','var')
        rot = 90;
    end
	while ~isDone
        figure(2);
        imshow(imrotate(imSmall,rot));
        axis equal;
        title('Rotate image to correct orientation');
        in = inputdlg({'Enter rotation angle [deg] (press ok twice when done)'},'Input',[1 40],{num2str(rot)});
        
        if isempty(in)
            disp('ABORTING!');
            return;
            %break;
        else
            rotNew = str2double(in{1});
            if (rotNew == rot)
                break;
            else
                rot = rotNew;
            end
        end
    end
    angles(si) = rot;
end

%% Write files to disk
disp('Writing Your Selection to Disk');
tic;
for si=1:length(slideSections)
    
    %Set an output directory
    localRawFolder = [tmpFolderSubjectFilePath '\Slides\' slideSections{si} '\Hist_Raw\'];
    mkdir(localRawFolder);
    
    rot = angles(si);
    roi = rois(si,:);
    
    %Generate images to save - overview #1
    imwrite(slideInfoIm,'SlideInfo.tif');
    imwrite(imrotate(wholeSlideIm,rot),[localRawFolder '\SlideOverview1.tif']);
    
    %Generate images to save - overview #2
    f = figure(3);
    imshow(lowResSlideIm);
    rectangle('Position',roi,'EdgeColor','r','LineWidth',2);
    fim = frame2im(getframe(f));
    imwrite(imrotate(fim,rot),[localRawFolder '\SlideOverview2.tif']);
    
    %Generate the real patch
    l=1;
    r = [roi(2) roi(2)+roi(4)]+roi(4)*0.05*[-1 1]; %Take a little extra!
    c = [roi(1) roi(1)+roi(3)]+roi(3)*0.05*[-1 1];
    Rows=r*info(l).Height/s(1);
    Cols=c*info(l).Width /s(2);
    im = imread(histologyFP,'Index',l,'PixelRegion',{Rows,Cols});
    im = imrotate(im,rot);
    imwrite(im,[localRawFolder '\Histo_20x.tif']);
end
toc;
%% Upload to cloud if required

if (~isDelayedUpload)
    %Upload
    awsCopyFileFolder(tmpFolderSubjectFilePath,subjectFolder);
    disp('Done');
end

%% Finish
outStatus = true;