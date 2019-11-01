%This script alignes histology slices with flourecence microscopy images
%If you just ran HistSVSImport - don't change anything! Just Run

%% Inputs
slidePath = [s3SubjectPath('05') 'Slides/Slide01_Section01/'];

%Notice:
%When running this script GUI will open, mark 4 matching points between the
%two images. Make sure to space points around.
%When done just close dialog box.
%To cancel (or flip image left - right) close figure without marking any points.

%If these varibles exist, it means we just imported the histology slides,
%we can use locally saved slides and save us some time
if exist('s3SlidesFolder','var') &&  exist('localRawsFolder','var')
    slidePaths = s3SlidesFolder;
    histRawPaths = localRawsFolder;
else
    slidePaths = {slidePath};
    histRawPaths = {[slidePath 'Hist_Raw/']};
end

%% Main Job
awsSetCredentials();

for si = 1:length(slidePaths)
    %% Load Histology & FM images, JSON as well
    slideJson = awsReadJSON([slidePaths{si} 'SlideConfig.json']);
    imFM = uint8(yOCTFromTif([slidePaths{si} slideJson.brightFieldImagePath]));
    ds=fileDatastore(awsModifyPathForCompetability([histRawPaths{si} 'Histo_*']),'ReadFcn',@imread);
    imHist=ds.read();
    
    logFolderPath = awsModifyPathForCompetability([slidePaths{si} '../../Log/04 Histology Preprocess/']);
    [~,sliceName] = fileparts([slidePaths{si}(1:end-1) '.a']);
    
    %% Prompt user to select some points
    for i=1:2
        [selectedImHistPoints,selectedImFMPoints] = cpselect(...
            imHist, ... Moved
            imFM, ... Bright field
            'Wait',true);
        if  isempty(selectedImHistPoints)
            if i==1
                %Try flipped image
                isHistImageFlipped = true;
                imHist = fliplr(imHist);
            else
                error('Aborting');
            end
        else
            isHistImageFlipped = false;
            break;
        end
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
    
    fileName = [sliceName '_HistFMRegistration.png'];
    saveas(h,fileName);
    awsCopyFileFolder(fileName,logFolderPath);
    
    %% Upload Hist Image to Cloud
    disp('Uploading Image');
    imwrite(imHistRegistered,'Histology.tif');
    awsCopyFileFolder('Histology.tif',slidePaths{si});
    
    %% Update JSON
    slideJson.histologyImageFilePath = 'Histology.tif';
    slideJson.FMHistologyAlignment.isHistologyFlipedLR = isHistImageFlipped;
    slideJson.FMHistologyAlignment.histology2FMTransform = tform.T;
    slideJson.FMHistologyAlignment.histologyImagePixelSizeBeforeAlignment_um = slideJson.FM.pixelSize_um*norm(tform.T(1:2,1));
    slideJson.FMHistologyAlignment.histologyImagePixelSizeAfterAlignment_um = slideJson.FM.pixelSize_um;
    awsWriteJSON(slideJson,[slidePaths{si} 'SlideConfig.json']); 
end