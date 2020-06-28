function outputFolder=generatePatchesFromImages(alignedImagesFolder,outputFolder, patchSize_pix, aspectRatio)
% This function takes image pairs and generates patches
%% Inputs

% Folder with aligned images (input folder)
if ~exist('alignedImagesFolder','var') || isempty(alignedImagesFolder)
    alignedImagesFolder = [pwd '\dataset_oct_histology\original_image_pairs\'];
end

% Patch size
if ~exist('patchSize_pix','var') || isempty(patchSize_pix)
    patchSize_pix = [512, 1024]; % Y,X
end

% Aspect ratio
% When aspectRatio = [1 1] pixel size in both axis is equal. (default)
% When aspectRatio = [1 0.5] pixel size in x direction is double than y
% direction. Meaning size of image along x will be 0.5 of original size.
% This allows to fill up a rectangular image to a square
if ~exist('aspectRatio','var') || isempty(aspectRatio)
    aspectRatio = [1 1]; %[Y,X]
end

% Folder to write patches to (output folder)
if ~exist('outputFolder','var') || isempty(outputFolder)
    aspectRatioText = '';
    if any(aspectRatio~=1)
        aspectRatioText = sprintf('_aspect_ratio_%.0f_%.0f',...
            1/aspectRatio(2),1/aspectRatio(1));
    end
    
    outputFolder = awsModifyPathForCompetability(...
        [alignedImagesFolder '..\patches_' ...
        sprintf('%dpx_%dpx%s',patchSize_pix(2),patchSize_pix(1),aspectRatioText) ...
        '\']);
end

% Patch overlap
patchOverlap_pix = patchSize_pix/2; % Pixels.

% Reject if not patchDataMinimumAbs is ment and not patchDataMinimumRelative
patchDataMinimumAbs = 0.3; % Reject patch if less than x% of its area is usable. Set to 1 to disable.
patchDataMinimumRelative = 0.5; %Reject patch if it is less than x% of the area of the first patch. Set to 1 to disable.

% Mirror flip patch as well.
%includeflip = true; 

%% Figure out input dataset
ds_A = fileDatastore(...
    awsModifyPathForCompetability([alignedImagesFolder '/*_A.jpg']),'ReadFcn',@imread);
ds_B = fileDatastore(...
    awsModifyPathForCompetability([alignedImagesFolder '/*_B.jpg']),'ReadFcn',@imread);

awsMkDir(outputFolder,true);

%% Add an empty image to the dataset (empty OCT and empty histology)
% These empty images allow the ML training to learn that empty slides are
% translated to empty slides.

im_bk = zeros(...
    patchSize_pix(1),... y
    patchSize_pix(2),... x
    3,'uint8');

imwrite( ...
    im_bk, ...
    GetCropFilePath('black_A.jpg', 0, outputFolder));
imwrite( ...
    im_bk, ...
    GetCropFilePath('black_B.jpg', 0, outputFolder));


%% Loop over all images to generate patches
for imageI=1:length(ds_A.Files)
    
    % Load Images
    im_A = ds_A.read;
    im_B = ds_B.read;
    
    % Check size
    sz_A = [size(im_A,1) size(im_A,2)];
    sz_B = [size(im_B,1) size(im_B,2)];
    if any(sz_A ~= sz_B)
        error('size of im_A is different from im_B for %s',ds_A.Files{imageI});
    end
    
    % Apply aspect ratio
    if any(aspectRatio ~= 1)
        % Compress image
        im_A = imresize(im_A, round(sz_A.*aspectRatio), 'Antialiasing', true, 'method', 'cubic');
        im_B = imresize(im_B, round(sz_B.*aspectRatio), 'Antialiasing', true, 'method', 'cubic');
    end
    clear('sz_A','sz_B');
    
    % Pad to match the minimal size of patch
    im_A = imPadToMeetPatchSize(im_A, patchSize_pix(2), patchSize_pix(1), 0);
    im_B = imPadToMeetPatchSize(im_B, patchSize_pix(2), patchSize_pix(1), 0);
    
    if ~strcmp(strrep(ds_A.Files{imageI},'_A.jpg',''), strrep(ds_B.Files{imageI},'_B.jpg',''))
        error('file names don''t match "%s" vs "%s"',ds_A.Files{imageI},ds_B.Files{imageI});
    end

    h = size(im_A,1);
    w = size(im_A,2);
    
    % In cases that image is only slightly bigger than the size that fits
    % in a patch, try to set the start point such that the least amount of
    % data is wasted, i.e. start in the middle
    
    % Number of patches that this image will be devided by (x direction)
    nXPatches = 1 + ...
        (w-patchSize_pix(2))/patchOverlap_pix(2); 
    nXPatches = floor(nXPatches);
    if nXPatches < 1
        nXPatches = 1;
    end
    
    % Residual pixels
    rx = w - ( patchSize_pix(2) + patchOverlap_pix(2)*(nXPatches - 1) );
    
    % Set start position to be the center of the residual
    x_Start = max([round(rx/2),1]);
    
    % loop through patches
    cropcount = 1;
    for y=1:patchOverlap_pix(1):(h-patchSize_pix(1))
        for x=x_Start:patchOverlap_pix(2):max([w-patchSize_pix(2),1])
            roiy = y:y+(patchSize_pix(1)-1);
            roix = x:x+(patchSize_pix(2)-1);

            % Reject image if # of non-zeros pixels greater than threshold
            goodPixels = sum(sum(im_B(roiy,roix,1) ~= 0));
            totalPixels = prod(patchSize_pix);
            if cropcount == 1
                goodPixelsInFirstPatch = goodPixels;
            end
            if (...
                (goodPixels/totalPixels<patchDataMinimumAbs) && ...
                (goodPixels/goodPixelsInFirstPatch<patchDataMinimumRelative))
                warning('%s have less than %.0f%% of usable pixels, or less than minimul relative good pixels, therefore is beeing skipped.', ...
                ds_A.Files{imageI},patchDataMinimumAbs*100);
            
                % Don't throw anything!
                % continue;
            end

            % crop images
            crop = im_A(roiy,roix,:);
            cropFilePath = GetCropFilePath(ds_A.Files{imageI}, cropcount, outputFolder);  
            imwrite(crop,cropFilePath);
            
            crop = im_B(roiy,roix,:);
            cropFilePath = GetCropFilePath(ds_B.Files{imageI}, cropcount, outputFolder);  
            imwrite(crop,cropFilePath);
            
            cropcount = cropcount + 1;
        end
    end
end

function cropFilePath = GetCropFilePath(imName, cropcount, outputFolder)

[~,cropFileName,tmp] = fileparts(imName);
cropFileName = [cropFileName tmp];
cropFileName = strrep(cropFileName,'_A.jpg',sprintf('_patch%02d_A.jpg',cropcount));
cropFileName = strrep(cropFileName,'_B.jpg',sprintf('_patch%02d_B.jpg',cropcount));
cropFilePath = awsModifyPathForCompetability([outputFolder '\' cropFileName]);
