function gatherAlignedImagesFromAllSubjects(outputFolder,...
    octBScanToUseAroundCenter,isAverageOCTBScans, outputImagePixelSize_um, ...
    minPatchSizeX_pix, minPatchSizeY_pix)
% This script gathers OCT & Histology images from all subjects in library

%% Inputs

% Main dataset folder to generate images to
if ~exist('outputFolder','var') || isempty(outputFolder)
    outputFolder = [pwd '\dataset_oct_histology\original_image_pairs\'];
end

% Which libraries to take images from
libraryNames = {'LC','LD','LE','LF'};

if ~exist('octBScanToUseAroundCenter','var') || isempty(octBScanToUseAroundCenter)
    %How many OCT slides to use, set to 0 if only to use the main one -1:1 to
    %use 1 micron ahead and 1 micron after
    octBScanToUseAroundCenter = (-2:2); % Can be 0, -2:2
end
if ~exist('isAverageOCTBScans','var') || isempty(isAverageOCTBScans)
    isAverageOCTBScans = true; % true means B scans to be averaged, false to generate individual images
end

% Magnification - Approximate Pixel Size
%           20x - 0.7 micron
%           10x - 1.0 micron
%            4x - 2.5 micron
% Source: https://www.amscope.com/camera-resolution
if ~exist('outputImagePixelSize_um','var') || isempty(outputImagePixelSize_um)
    outputImagePixelSize_um = 1;
end

if ~exist('minPatchSizeX_pix','var') || isempty(minPatchSizeX_pix)
    minPatchSizeX_pix = round(256*0.7);
end
if ~exist('minPatchSizeY_pix','var') || isempty(minPatchSizeY_pix)
    minPatchSizeY_pix = round(256*0.7);
end

%% Set inputs we would like to keep in to JSON
clear json
json.libraryNames = libraryNames;
json.octBScanToUseAroundCenter = octBScanToUseAroundCenter;
json.isAverageOCTBScans = isAverageOCTBScans;
json.imagesPixelSize_um = outputImagePixelSize_um;

%% Setup outputfolder
outputFolder = awsModifyPathForCompetability([outputFolder '\']);
awsMkDir(outputFolder,true);

%% Load slides information
st = loadStatusReportByLibrary(libraryNames);
isUsable = find(st.isUsableInML);
%isUsable = 1:length(st.isUsableInML); % For debugging purposes get all slides

%% Do the work
fprintf('Gathering images from %d valid sections. Wait for 10 stars ... [ ',length(isUsable)); tic;
imwritefun = @(im,path)(imwrite(im,path,'Quality',100));
for iSlide=1:length(isUsable)
    if mod(iSlide,round(length(isUsable)/10)) == 0
        fprintf('* ');
    end
    subjectName = st.subjectNames{isUsable(iSlide)};
    sectionName = st.sectionNames{isUsable(iSlide)};
    sectionPath = st.sectionPahts{isUsable(iSlide)};
    outputFilePathTemplate = sprintf('%s%s-%s_y%%s%%.0f_%%s.jpg' ,...
        outputFolder,subjectName, sectionName);
    outputFilePathTemplate = strrep(outputFilePathTemplate,'\','\\');
    
    % Load slide config
    slideConfig = awsReadJSON([sectionPath 'SlideConfig.json']);
    
    % Load data - H&E  
    img_he = awsimread([sectionPath slideConfig.alignedImagePath_Histology]);
    
    % Load data - OCT (and average if needed)
    if length(octBScanToUseAroundCenter) == 1 && octBScanToUseAroundCenter(1) == 0 %Load just the central slide
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
        img_oct = img_oct(:,:,(size(img_oct,3)+1)/2 + octBScanToUseAroundCenter);
        
        % Average if needed 
        if(json.isAverageOCTBScans)
            %img_oct = squeeze(log(mean(exp(img_oct),3))); % Linear scale averaging. 
            img_oct = squeeze(mean(img_oct,3)); % Log scale averaging.
        end
    end
    
    % Load data - mask
    img_mask = yOCTFromTif([sectionPath slideConfig.alignedImagePath_Mask]);
    
    % Rescale image - compute scale factor
    img_pixelSize_um = diff(metadata.x.values(1:2));
    scaleFactor = outputImagePixelSize_um/img_pixelSize_um;
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
    
    % Size check
    if size(img_mask,1) < minPatchSizeY_pix || size(img_mask,2) < minPatchSizeX_pix
        % Too small, skip
        continue;
    end

    % Convert OCT to grayscale (reserve black color to NaN)
    img_oct = scale0To255(img_oct);
    
    % Convert mask to numbers
    img_mask(isnan(img_mask)) = 10;
    
    % Save OCT images - set y text
    if size(img_oct,3) == 1
        % Use the average
        y = mean(octBScanToUseAroundCenter);
    else
        y = octBScanToUseAroundCenter;
    end
    ySign = cell(size(y));
    for i=1:length(ySign)
        if (y(i) < 0)
            ySign{i} = 'm';
        elseif (y(i) >= 0)
            ySign{i} = 'p';
        else
            ySign{i} = '';
        end
    end
    
    % Save OCT images
    for i=1:length(y)
        imwritefun(squeeze(img_oct(:,:,i)), ...
            sprintf(outputFilePathTemplate,ySign{i},abs(y(i)),'A'));
    end
    
    % Save image
    imwritefun(img_he, sprintf(outputFilePathTemplate,'p',0,'B'));
end
fprintf('] Done! Took %.0f minutes.\n',toc()/60);

%% Write configuration to log
json.subjectNamesUsed = unique(st.subjectNames(isUsable));
awsWriteJSON(json,[outputFolder 'DatasetConfig.json']);