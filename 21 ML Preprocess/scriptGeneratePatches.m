% This script generate image patches from all subjects

%% Inputs

% Which libraries to take images from
libraryNames = {'LE','LF'};

% Output patches defenitions.
patchSizeX_pix = 256; % Patch size (pixels)
patchSizeY_pix = 256;

% Magnification - Approximate Pixel Size
%           20x - 0.7 micron
%           10x - 1.1 micron
%            4x - 2.7 micron
% Source: https://www.amscope.com/camera-resolution
patchPixelSize = 2; % microns, original image size: 1um.

% Where to write patches to:
outputFolder = 'Patches/';

% How to generate patches.
patchOverlap = 32; % Pixels.
patchDataMinimum = 0.5; % Reject patch if less than x% of its area is usable.
includeflip = true; % Mirror flip patch as well.

%% Jenkins override of inputs
if exist('patchFolder_','var')
    outputFolder = patchFolder_;
end
if exist('patchPixelSize_','var')
    patchPixelSize = patchPixelSize_;
end
if exist('patchSizeX_pix_','var')
    patchSizeX_pix = patchSizeX_pix_;
end
if exist('patchSizeY_pix_','var')
    patchSizeY_pix = patchSizeY_pix_;
end

%% Clear output folder
outputFolder = awsModifyPathForCompetability([pwd '/' outputFolder '/']);
if exist(outputFolder,'dir')
    rmdir(outputFolder,'s');
end
mkdir(outputFolder);

%% Load slides information
st = loadStatusReportByLibrary(libraryNames);

%% Do the work
isUsable = find(st.isUsableInML);
fprintf('Generating patches from %d valid sections. Wait for 10 stars ... [ ',length(isUsable)); tic;
imwritefun = @(im,path)(imwrite(im,path,'Quality',100));
cropcountTotal = 1;
for iSlide=1:length(isUsable)
    if mod(iSlide,round(length(isUsable)/10)) == 0
        fprintf('* ');
    end
    subjectName = st.subjectNames{isUsable(iSlide)};
    sectionName = st.sectionNames{isUsable(iSlide)};
    sectionPath = st.sectionPahts{isUsable(iSlide)};
    outputFilePathTemplate = sprintf('%s%%d_%s-%s_Patch%%02d.jpg' ,...
        outputFolder,subjectName, sectionName);
    outputFilePathTemplate = strrep(outputFilePathTemplate,'\','\\');
    
    % Load data  
    img_he = awsimread([sectionPath '/HistologyAligned.tif']);
    [img_oct, metadata] = yOCTFromTif([sectionPath '/OCTAligned.tif']);
    img_mask = yOCTFromTif([sectionPath '/MaskAligned.tif']);
    img_pixelSize_um = diff(metadata.x.values(1:2));
    scaleFactor = patchPixelSize/img_pixelSize_um;
    if round(scaleFactor) ~= scaleFactor
        error('Scaling factor should be an integer, adjust patchPixelSize');
    end
    
    % Rescale image
    img_he =  imresize(img_he, 1/scaleFactor, 'Antialiasing', true, 'method', 'cubic');
    img_oct = imresize(img_oct, 1/scaleFactor, 'Antialiasing', true, 'method', 'cubic');
    img_mask = imresize(img_mask, 1/scaleFactor, 'Antialiasing', true, 'method', 'cubic');
    
    % Apply mask
    img_he(repmat(img_mask >= 0.2,[1,1,3])) = NaN;
    img_oct(img_mask >= 0.2) = NaN;
    
    % Crop everything outside of mask
    rowToCrop = find(~any(~isnan(img_oct),2));
    img_he(rowToCrop,:,:) = [];
    img_oct(rowToCrop,:) = [];
    img_mask(rowToCrop,:) = [];
    colToCrop = find(~any(~isnan(img_oct),1));
    img_he(:,colToCrop,:) = [];
    img_oct(:,colToCrop) = [];
    img_mask(:,colToCrop) = [];

    % Convert OCT to grayscale (reserve black color to NaN)
    img_oct = repmat(scale0To255(img_oct),[1 1 3]);
     
    % Pad with 0s if we cropped too much
    img_he = imPadToMeetPatchSize(img_he, patchSizeX_pix, patchSizeY_pix, 0);
    img_oct = imPadToMeetPatchSize(img_oct, patchSizeX_pix, patchSizeY_pix, 0);
    img_mask = imPadToMeetPatchSize(img_mask, patchSizeX_pix, patchSizeY_pix, 10); 
    
    % define h -height and w-width of images after downsize
    h=size(img_he,1); w=size(img_he,2);
    
    % Recolor to identify empty regions. (no value backgroud)
    noValueBackground = [0,0,0]; % Black background.
    %noValueBackground = [0,255,0]; % Green background.
    img_he = imReColor(img_he,[0 0 0],noValueBackground); %RGB
    img_oct = imReColor(img_oct,[0 0 0],noValueBackground); %RGB
    
    %% Generate patches 
    if h<patchSizeY_pix || w<patchSizeX_pix
        error('Should never happen');
        %this image is too small to generate patches.
    end 

    % loop through patches
    cropcount = 1;
    for y=1:patchOverlap:(h-patchSizeY_pix)
        for x =1:patchOverlap:(w-patchSizeX_pix)
            roiy = y:y+(patchSizeY_pix-1);
            roix = x:x+(patchSizeX_pix-1);

            % Reject image if # of non-zeros pixels greater than threshold
            goodPixels = sum(sum(img_mask(roiy,roix) < 0.2));
            totalPixels = patchSizeX_pix*patchSizeY_pix;
            if goodPixels/totalPixels<patchDataMinimum
                warning('%s-%s have less than %.0f%% of usable pixel, therefore is beeing skipped.', ...
                subjectName,sectionName,patchDataMinimum*100);
                continue;
            end

            % crop images
            crop_he = img_he(roiy,roix,:);
            crop_oct =img_oct(roiy,roix,:);

            % combine images
            outimg = [crop_he, crop_oct];
            % write image
            imwritefun(outimg, sprintf(outputFilePathTemplate,0,cropcount));

            % write flippled image
            if includeflip 
               outimg = [fliplr(crop_he), fliplr(crop_oct)];
               imwritefun(outimg, sprintf(outputFilePathTemplate,1,cropcount));
            end

            cropcountTotal = cropcountTotal + 1;
            cropcount = cropcount + 1;
        end
    end
end
fprintf('] Done! Took %.0f minutes.\n',toc()/60);
fprintf('Generated %d patches.\n',cropcountTotal*2);