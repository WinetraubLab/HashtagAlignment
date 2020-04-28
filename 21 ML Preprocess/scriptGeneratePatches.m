% This script generate image patches from all subjects

%% Inputs

% Which libraries to take images from
libraryNames = {'LC','LD','LE','LF'};

% Output patches defenitions.
patchSizeX_pix = 1024; % Patch size (pixels)
patchSizeY_pix = 512;

% Magnification - Approximate Pixel Size
%           20x - 0.7 micron
%           10x - 1.0 micron
%            4x - 2.5 micron
% Source: https://www.amscope.com/camera-resolution
patchPixelSize = 1; % microns, original image size: 1um.

% Where to write patches to:
outputFolder = 'Patches/';

% How to generate patches.
patchOverlapX_pix = patchSizeX_pix/2; % Pixels.
patchOverlapY_pix = patchSizeY_pix/2; % Pixels.
% Reject if not patchDataMinimumAbs is ment and not patchDataMinimumRelative
patchDataMinimumAbs = 0.3; % Reject patch if less than x% of its area is usable. Set to 1 to disable.
patchDataMinimumRelative = 0.5; %Reject patch if it is less than x% of the area of the first patch. Set to 1 to disable.
includeflip = true; % Mirror flip patch as well.

%How many OCT slides to use, set to 0 if only to use the main one -1:1 to
%use 1 micron ahead and 1 micron after
octBScansToUse = -2:2; % Can be 0, -2:2
octOutputType = 2; %- 1 means all B scans will be placed in the image side by side.
                   %- 2 means B scans will be averaged to generate one image.
                   
% Should OCT & Histology be concatinated together in the same image?
% If not, will be generated as seperate images _A and _B
isConcatinateOCTHistologyImages = false;

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
if exist('isConcatinateOCTHistologyImages_','var')
    isConcatinateOCTHistologyImages = isConcatinateOCTHistologyImages_;
end

%% Clear output folder
if (~strncmp(outputFolder,'//',2) && ~outputFolder(2) == ':')
    % Path is relative, make it absolute
    outputFolder = awsModifyPathForCompetability([pwd '/' outputFolder '/']);
else
    outputFolder = awsModifyPathForCompetability([outputFolder '/']);
end
if exist(outputFolder,'dir')
    rmdir(outputFolder,'s');
end
mkdir(outputFolder);

%% Load slides information
st = loadStatusReportByLibrary(libraryNames);
isUsable = find(st.isUsableInML);
%isUsable = 1:length(st.isUsableInML); % For debugging purposes get all slides

%% Write configuration to log
subjectNamesUsed = st.subjectNames{isUsable};
sectionNames = st.subjectNames{isUsable};
varNames=who;
json_allVaribels =[];
for i=1:length(varNames)
    json_allVaribels.(varNames{i}) = eval(varNames{i});
end
disp('Configuration used for running this script:');
json_allVaribels = rmfield(json_allVaribels,'st');
json_allVaribels = rmfield(json_allVaribels,'isUsable');
%json_allVaribels = rmfield(json_allVaribels,'varNames');
json_allVaribels

awsWriteJSON(json_allVaribels,[outputFolder 'ImageSetDefenition.json']);

%% Do the work
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
    outputFilePathTemplate = sprintf('%s%%d_%s-%s_Patch%%02d%%s.jpg' ,...
        outputFolder,subjectName, sectionName);
    outputFilePathTemplate = strrep(outputFilePathTemplate,'\','\\');
    
    % Load slide config
    slideConfig = awsReadJSON([sectionPath 'SlideConfig.json']);
    
    % Load data - H&E  
    img_he = awsimread([sectionPath slideConfig.alignedImagePath_Histology]);
    
    % Load data - OCT (and average if needed)
    if length(octBScansToUse) == 1 && octBScansToUse(1) == 0 %Load just the central slide
        
        if ~isfield(slideConfig,'alignedImagePath_OCT')
            warning('%s %s doesn''t have alignedImagePath_OCT, skipping',...
                subjectName,sectionName)
            continue;
        end
        
        [img_oct, metadata] = yOCTFromTif([sectionPath slideConfig.alignedImagePath_OCT]);
    else
        if ~isfield(slideConfig,'alignedImagePath_OCTStack')
            warning('%s %s doesn''t have alignedImagePath_OCTStack, skipping',...
                subjectName,sectionName)
            continue;
        end
        % We need the stack
        [img_oct, metadata] = yOCTFromTif([sectionPath slideConfig.alignedImagePath_OCTStack]);
        
        % Remove not used parts of the oct image
        img_oct = img_oct(:,:,(size(img_oct,3)+1)/2 + octBScansToUse);
        
        % Average if needed 
        if(octOutputType==2)
            %img_oct = squeeze(log(mean(exp(img_oct),3))); % Linear scale averaging. 
            img_oct = squeeze(mean(img_oct,3)); % Log scale averaging.
        end
    end
    
    % Load data - mask
    img_mask = yOCTFromTif([sectionPath slideConfig.alignedImagePath_Mask]);
    
    % Rescale image - compute scale factor
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
    img_oct(repmat(img_mask >= 0.2,[1,1,size(img_oct,3)])) = NaN;
    img_mask(img_mask >= 0.2) = NaN;
    
    % Crop everything outside of mask
    rowToCrop = find(~any(~isnan(img_mask),2));
    img_he(rowToCrop,:,:) = [];
    img_oct(rowToCrop,:,:) = [];
    img_mask(rowToCrop,:) = [];
    colToCrop = find(~any(~isnan(img_mask),1));
    img_he(:,colToCrop,:) = [];
    img_oct(:,colToCrop,:) = [];
    img_mask(:,colToCrop) = [];

    % Convert OCT to grayscale (reserve black color to NaN)
    img_oct = scale0To255(img_oct);
    
    % Convert mask to numbers
    img_mask(isnan(img_mask)) = 10;
     
    % Pad with 0s if we cropped too much, mask pads with 10
    img_he = imPadToMeetPatchSize(img_he, patchSizeX_pix, patchSizeY_pix, 0);
    img_oct = imPadToMeetPatchSize(img_oct, patchSizeX_pix, patchSizeY_pix, 0);
    img_mask = imPadToMeetPatchSize(img_mask, patchSizeX_pix, patchSizeY_pix, 10); 
    
    % define h -height and w-width of images after downsize
    h=size(img_he,1); w=size(img_he,2);
    
    %% Generate patches 
    if h<patchSizeY_pix || w<patchSizeX_pix
        error('Should never happen');
        %this image is too small to generate patches.
    end 

    % loop through patches
    cropcount = 1;
    for y=1:patchOverlapY_pix:(h-patchSizeY_pix)
        for x=1:patchOverlapX_pix:(w-patchSizeX_pix)
            roiy = y:y+(patchSizeY_pix-1);
            roix = x:x+(patchSizeX_pix-1);

            % Reject image if # of non-zeros pixels greater than threshold
            goodPixels = sum(sum(img_mask(roiy,roix) < 0.2));
            totalPixels = patchSizeX_pix*patchSizeY_pix;
            if x==1 && y==1
                goodPixelsInFirstPatch = goodPixels;
            end
            if (...
                (goodPixels/totalPixels<patchDataMinimumAbs) && ...
                (goodPixels/goodPixelsInFirstPatch<patchDataMinimumRelative))
                warning('%s-%s have less than %.0f%% of usable pixels, or less than minimul relative good pixels, therefore is beeing skipped.', ...
                subjectName,sectionName,patchDataMinimumAbs*100);
                continue;
            end

            % crop images
            crop_he = img_he(roiy,roix,:);
            crop_oct =img_oct(roiy,roix,:);
            
            % reshape crop of oct to include all images side by side
            crop_oct = reshape(...
                crop_oct,[patchSizeY_pix patchSizeX_pix*size(crop_oct,3)]);
            crop_oct = repmat(crop_oct,[1 1 3]); % Convert to rgb

            % combine images & write
            if isConcatinateOCTHistologyImages
                outimg = [crop_oct, crop_he];
                imwritefun(outimg, sprintf(outputFilePathTemplate,0,cropcount,''));
            else
                imwritefun(crop_oct, sprintf(outputFilePathTemplate,0,cropcount,'_A'));
                imwritefun(crop_he, sprintf(outputFilePathTemplate,0,cropcount,'_B'));
            end

            % write flippled image
            if includeflip  
               if isConcatinateOCTHistologyImages
                    outimg = [fliplr(crop_oct), fliplr(crop_he)];
                    imwritefun(outimg, sprintf(outputFilePathTemplate,1,cropcount,''));
                else
                    imwritefun(fliplr(crop_oct), sprintf(outputFilePathTemplate,1,cropcount,'_A'));
                    imwritefun(fliplr(crop_he), sprintf(outputFilePathTemplate,1,cropcount,'_B'));
                end
            end

            cropcountTotal = cropcountTotal + 1;
            cropcount = cropcount + 1;
        end
    end
end
fprintf('] Done! Took %.0f minutes.\n',toc()/60);
fprintf('Generated %d patches.\n',cropcountTotal*2);