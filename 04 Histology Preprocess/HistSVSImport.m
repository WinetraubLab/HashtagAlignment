%This script imports H&E Images from SVS format

%% Inputs
tifInFP = '1000418.svs';

subject = 'LC-05';
slide = '01';
subjectFolder = s3SubjectPath(subject(4:end),subject(1:2));
sections = {'01','02','03'};


%% Ask user to mark all sections

%Load High Level Data
info=imfinfo(tifInFP);
slideInfoIm  =imread(tifInFP,'Index',6);
wholeSlideIm =imread(tifInFP,'Index',7);
lowResSlideIm=imread(tifInFP,'Index',2);

%Make the main figure
figure(1);
subplot(3,3,1);
imshow(slideInfoIm);
subplot(3,3,[2 3]);
imshow(wholeSlideIm);
ax =  subplot(3,3,4:9);
imshow(lowResSlideIm);
s = size(lowResSlideIm); s = s(1:2);

rois = zeros(length(sections),4);
angles = zeros(length(sections),1);
for si=1:length(sections)
    figure(1);
    subplot(ax);
    title([subject ', Please select Slide' slide ' Section' sections{si} ' Press Space When Done']);
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
    imSmall = imread(tifInFP,'Index',l,'PixelRegion',{Rows,Cols});
    isDone = false;
    if ~exist('rot','var')
        rot = 0;
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

%% Clear local folder
outputRootFolder = 'out\';
if exist(outputRootFolder,'dir')
    rmdir(outputRootFolder,'s');
end
mkdir(outputRootFolder);

%% Upload to the cloud
s3SlidesFolder = cell(si,1);
localRawsFolder = cell(si,1);
disp('Generating Images...');
for si=1:length(sections)
    s3SlideFolder = [subjectFolder 'Slides/Slide' slide '_Section' sections{si} '/'];
    s3SlidesFolder{si} = s3SlideFolder;
    
    %Set an output directory
    localRawFolder = [outputRootFolder 'Slide' slide '_Section' sections{si} '\Hist_Raw\'];
    mkdir(localRawFolder);
    localRawsFolder{si} = localRawFolder;
    
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
    im = imread(tifInFP,'Index',l,'PixelRegion',{Rows,Cols});
    im = imrotate(im,rot);
    imwrite(im,[localRawFolder '\Histo_20x.tif']);
end

%Upload
awsCopyFileFolder(outputRootFolder,[subjectFolder 'Slides/']);

disp('Done');