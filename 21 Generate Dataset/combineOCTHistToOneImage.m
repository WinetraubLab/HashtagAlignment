function combineOCTHistToOneImage(alignedImagesFolder,outputFolder)
% This function takes image pairs and generates a nice overview image
%% Inputs

% Folder with aligned images (input folder)
if ~exist('alignedImagesFolder','var') || isempty(alignedImagesFolder)
    alignedImagesFolder = [pwd '\dataset_oct_histology\original_image_pairs\'];
end

% Folder to write patches to (output folder)
if ~exist('outputFolder','var') || isempty(outputFolder)
    outputFolder = [pwd '\dataset_oct_histology\original_image_pairs_view_for_user\'];
end

%% Figure out input dataset
ds_A = fileDatastore(...
    awsModifyPathForCompetability([alignedImagesFolder '/*_A.jpg']),'ReadFcn',@imread);
ds_B = fileDatastore(...
    awsModifyPathForCompetability([alignedImagesFolder '/*_B.jpg']),'ReadFcn',@imread);

awsMkDir(outputFolder,true);

json = awsReadJSON([alignedImagesFolder '/DatasetConfig.json']);
imagesPixelSize_um = json.imagesPixelSize_um;

%% Loop over all images to nice looking images
for imageI=1:length(ds_A.Files)
    im_A = ds_A.read;
    im_B = ds_B.read;
    
    [~,fn,tmp] = fileparts(ds_A.Files{imageI});
    fn = [fn tmp];
    fn = strrep(fn,'_A.jpg','.jpg');
    nname = strrep(fn,'_','-');
     
    if ~strcmp(strrep(ds_A.Files{imageI},'_A.jpg',''), strrep(ds_B.Files{imageI},'_B.jpg',''))
        error('file names don''t match "%s" vs "%s"',ds_A.Files{imageI},ds_B.Files{imageI});
    end
    sz_A = [size(im_A,1) size(im_A,2)];
    sz_B = [size(im_B,1) size(im_B,2)];
    if any(sz_A ~= sz_B)
        error('size of im_A is different from im_B for %s',ds_A.Files{imageI});
    end
    
    % Combine
    % Concatinate all files
    imAll = [repmat(im_A,1,1,3) ; im_B];

    % Add scale bar
    scalebarLength = 100/imagesPixelSize_um;
    imAll(end-(20:30),20+(1:scalebarLength),:) = 256;

    imshow(imAll);
     title(sprintf('%s (%s)',nname,pixelSizeToMagnification(imagesPixelSize_um)));

    %text(20+scalebarLength+10,size(imAll,1)-25,'100\mum','Color',[1 1 1],'FontWeight','bold');
    text(20,size(imAll,1)-25,'100\mum','FontSize',8);
    
    % Save
    awsSaveMatlabFigure(gcf,[outputFolder '/' fn],false,false);
end