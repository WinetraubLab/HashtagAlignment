% This script loads results from checkpoint, makes a folder with all input
% images as well as test results

mainFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/_MLModels/2020-05-10 Pix2PixHD/';

inputDataSet = awsModifyPathForCompetability([mainFolder '/ml/dataset_oct_histology/']);
testResults = awsModifyPathForCompetability([mainFolder '/ml/results/MyModel/test_latest/images/']);

outputFolder = 'Output\';

%% Gather general Information
mainFolder = awsModifyPathForCompetability([mainFolder '/']);
runConfigJson = awsReadJSON([mainFolder 'RunConfig.json']);

imagesPixelSize_um = runConfigJson.patchPixelSize; %replace with:patchImagePixelSize_um

if (runConfigJson.isConcatinateOCTHistologyImages)
    error('Doesn''t know how to work with concatinated images, just images that are split apart');
end

awsMkDir(outputFolder,true); % Make a folder and cleanuup

%% Train set
octFolder = [inputDataSet 'train_A/'];
histRealFolder = [inputDataSet 'train_B/'];
fnames = awsls(octFolder);
fnames(cellfun(@(x)(strncmp(x,'1_',2)),fnames)) = []; % Remove flipped images

awsMkDir([outputFolder '/train/'],true);

for i=1:length(fnames)
    % Init
    fn = fnames{i};
    nname = fn(3:(strfind(fn,'_Patch')-1));
    nname=strrep(nname,'_','-');
    
    % Load files
    imOCT = awsimread([octFolder fn]);
    imHistReal = awsimread([histRealFolder fn]);
    
    % Combine
    imAll = myCombine(imOCT,imHistReal,[],nname,imagesPixelSize_um);
    
    % Save
    imwrite(imAll,[outputFolder '/train/' fnames{i}]);
end

%% Test set
octFolder = [inputDataSet 'test_A/'];
histRealFolder = [inputDataSet 'test_B/'];
fnames = awsls(octFolder);
fnames(cellfun(@(x)(strncmp(x,'1_',2)),fnames)) = []; % Remove flipped images

awsMkDir([outputFolder '/test/'],true);

for i=1:length(fnames)
    % Init
    fn = fnames{i};
    nname = fn(3:(strfind(fn,'_Patch')-1));
    nname=strrep(nname,'_','-');
    
    % Load files
    imOCT = awsimread([octFolder fn]);
    imHistReal = awsimread([histRealFolder fn]);
    imhistFake = awsimread([testResults strrep(fn,'.jpg','_synthesized_image.jpg')]);
    
    % Combine
    imAll = myCombine(imOCT,imHistReal,imhistFake,nname,imagesPixelSize_um);
    
    % Save
    imwrite(imAll,[outputFolder '/test/' fnames{i}]);
end

%% Combine & Write a single file
function imAll = myCombine(imOCT,imHistReal,imHistFake,nname,imagesPixelSize_um)
if ~exist('imHistFake','var')
    imHistFake = [];
end

% Concatinate all files
imAll = [imOCT ; imHistFake; imHistReal];

% Add name
imAll = AddTextToImage(imAll,nname,[1,10],[1 1 1],'Arial');

% Add scale bar
scalebarLength = 100/imagesPixelSize_um;
imAll(end-(20:30),20+(1:scalebarLength),:) = 256;
imAll = AddTextToImage(imAll,'100um',[size(imAll,1)-30-20,20+scalebarLength+20],[1 1 1],'Arial');

end