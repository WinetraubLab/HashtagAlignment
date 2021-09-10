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
% Any fileDatastore request to AWS S3 is limited to 1000 files in 
% MATLAB 2021a. Due to this bug, we have replaced all calls to 
% fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
% 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
ds_A = fileDatastore(...
    awsModifyPathForCompetability([alignedImagesFolder '/*_A.jpg']),'ReadFcn',@imread);
ds_B = fileDatastore(...
    awsModifyPathForCompetability([alignedImagesFolder '/*_B.jpg']),'ReadFcn',@imread);

ds_json = fileDatastore(...
    awsModifyPathForCompetability([alignedImagesFolder '/*_.json']),'ReadFcn',@awsReadJSON);

awsMkDir(outputFolder,true);

json = awsReadJSON([alignedImagesFolder '/DatasetConfig.json']);
imagesPixelSize_um = json.imagesPixelSize_um;

%% Loop over all images to nice looking images
for imageI=1:length(ds_A.Files)
    im_A = ds_A.read;
    im_B = ds_B.read;
    json = ds_json.read;
    
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

    subplot(1,1,1);
    subplot(1,4,1:3)
    imshow(imAll);
    title(sprintf('%s (%s)',nname,pixelSizeToMagnification(imagesPixelSize_um)));

    %text(20+scalebarLength+10,size(imAll,1)-25,'100\mum','Color',[1 1 1],'FontWeight','bold');
    text(20,size(imAll,1)-25,'100\mum','FontSize',8);
    
    % Write info about this image
    txt = jsonencode(json.QAInfo);txt([1 end-1 end]) = []; 
    txt = strrep(txt,'"','');
    txt = strrep(txt,'{',[newline '--------' newline]);
    txt = strrep(txt,'}',newline);
    txt = strrep(txt,',',newline);
    txt = strrep(txt,'_',' ');
    txt = strrep(txt,':',': ');
    subplot(1,4,4)
    text(0,0.5,txt,'Color','k','HorizontalAlignment','left','VerticalAlignment','middle');
    title('QA Information');
    axis off;
    
    % Save
    awsSaveMatlabFigure(gcf,[outputFolder '/' fn],true,false);
end