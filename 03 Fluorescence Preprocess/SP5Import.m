%This script imports SP5 Fluorescence images 

%% Inputs

%Where to upload data
s3Dir = s3SubjectPath('01');

% Not used, algorithm figures out itself
%slideNumber = 1;
%sectionNumber = 1;

%Pointer to the folder structure, expecting [folderStructurePath '\slideX\section Y']
%In each section we will need to have the tif, and MetaData xml
folderStructurePath = '\\171.65.17.174\e\Caroline\OCT-Histology\LE\LE-01\slide 1\sec 1\';

%Fluorescence Image Path of one og
%fp = '\\171.65.17.174\MATLAB_Share\Yonatan\Edwin SP5\LB\S1\slide 1\sec 1\Experiment_TileScan_005_Merging001_z0_ch01.tif';

%Chanel
flourescenceChanel = 0;
brightfieldChanel = 1;
beadsChanel = 2; % set to [] if no beads chanel exists

angRotate = 180;

%% Jenkins
if exist('s3Dir_','var')
    s3Dir = s3Dir_;
    folderStructurePath = folderStructurePath_;
    angRotate = angRotate_;
end

%% Get files in folder
folderStructurePath = strrep(folderStructurePath,'"',''); %Remove "
folderStructurePath = [folderStructurePath '\'];
if ~exist(folderStructurePath,'dir')
    error('Please provide a valid folder path. Got: %s',folderStructurePath);
end

dsXml = fileDatastore(folderStructurePath,'ReadFcn',@(x)(x),'FileExtensions','.xml','IncludeSubfolders',true);
xmlFiles = dsXml.Files;

folders = cellfun(@(x)fileparts(x),xmlFiles,'UniformOutput',false);
folders = unique(folders);
folders(cellfun(@(x)~contains(lower(x),'slide'),folders)) = []; %Delete folders which don't have 'slide' in their name
folders= cellfun(@(x)strrep(x,'\MetaData',''),folders,'UniformOutput',false);

%% Read StackConfig.json to make sure section naming is consistent with instructions
StackConfig = awsReadJSON([s3Dir '/Slides/StackConfig.json']);
sectionNames = stackConfig.sections.names;

%% Loop for each folder extract data
disp(' '); disp('Looping Over All Folders');
for i=1:length(folders)
folder = folders{i};

%% Find a tif file, and slide & section
ds = fileDatastore(folder,'FileExtensions','.tif','ReadFcn',@(x)(x));
fp = ds.Files{1};

slideNumber = NaN;
sectionNumber = NaN;
sp = split(folder,'\');
sp = sp(end+(-1:0));
for j=1:length(sp)
    if (contains(lower(sp{j}),'slide'))
        d = sscanf(sp{j},'%s%d');
        slideNumber = d(end);
    elseif (contains(lower(sp{j}),'sec'))
        d = sscanf(sp{j},'%s%d');
        sectionNumber = d(end);
    end
end
if(isnan(slideNumber) || isnan(sectionNumber))
    error('Could''nt interpert section and or slide from: %s',folder);
end

fprintf('Processing: %s (slide %d, section %d)\n',folder,slideNumber,sectionNumber);

%% Import
json = [];
json.version = 1.2;

%Split file components
[folder,fileName] = fileparts(fp);
folder = [folder '\'];
fileName = fileName(1:(strfind(fileName,'_ch0')-1)); %Trim chanel
fileName = replace(fileName,'_z0','');

ds = fileDatastore([folder fileName '*'],'ReadFcn',@(x)(x));
files = ds.Files;

flourescenceImagePath = files(cellfun(@(x)(contains(x,sprintf('ch%02d',flourescenceChanel))),files));
if length(flourescenceImagePath) ~= 1
    error('Could not find one file with _ch%02d',flourescenceChanel);
end
flourescenceImagePath = flourescenceImagePath{:};
   
brightfieldImagePath = files(cellfun(@(x)(contains(x,sprintf('ch%02d',brightfieldChanel))),files));
if length(brightfieldImagePath) ~= 1
    warning('Could not find one file with _ch%02d (bright field)',brightfieldChanel);
    brightfieldImagePath = '';
else
    brightfieldImagePath = brightfieldImagePath{:};
end

beadsImagePath = files(cellfun(@(x)(contains(x,sprintf('ch%02d',beadsChanel))),files));
if length(beadsImagePath) ~= 1
    warning('Could not find one file with _ch%02d (beads channel)',beadsChanel);
    beadsImagePath = '';
else
    beadsImagePath = beadsImagePath{:};
end

%% Read pixel size from meta data

%Read subfolders
ds = fileDatastore(folder,'ReadFcn',@(x)(x),'IncludeSubfolders',true,'FileExtensions','.xml');
files = ds.Files;

fileToUse = cellfun(@(x)(contains(lower(x),'_properties.xml') & contains(x,fileName)),files);
if sum(fileToUse) ~= 1
    error('Could not find the right propreties xml here: %s, that has this file name: %s',folder,fileName);
end
xmlFilePath = files{fileToUse};

x = xml2struct(xmlFilePath);

xAttributes = x.Data.Image.ImageDescription.Dimensions.DimensionDescription{1}.Attributes;
yAttributes = x.Data.Image.ImageDescription.Dimensions.DimensionDescription{2}.Attributes;

xRes = str2double(xAttributes.Length)/str2double(xAttributes.NumberOfElements)*1000;
yRes = str2double(yAttributes.Length)/str2double(yAttributes.NumberOfElements)*1000;

json.FM.pixelSize_um = mean([xRes,yRes]);
fprintf('xRes/yRes-1 = %.5f\n',xRes/yRes-1);
fprintf('xRes = %.5f[um/pix] yRes = %.5f[um/pix]\n',xRes,yRes);
if (abs(xRes/yRes-1) > 0.01)
    error('Large error between x & y resolutions: %.3f[um/pix] vs %.3f[um/pix]. Whats up with that',xRes,yRes);
end

tmp = dir(xmlFilePath);
json.FM.imagedAt = datestr(tmp(1).datenum);

%% Rotate & Present
fprintf('Rotating image by %.0f[deg] counter clockwise\n',angRotate);
flourescenceIm = imrotate(imread(flourescenceImagePath),angRotate);
if ~isempty(brightfieldImagePath)
    brightfieldIm = imrotate(imread(brightfieldImagePath),angRotate);
end
if ~isempty(beadsImagePath)
    beadsIm = imrotate(imread(beadsImagePath),angRotate);
end

imshow(flourescenceIm);
title(sprintf('Are the lines at the top of the flourescence image?, Pixel Size %.2f%s',json.FM.pixelSize_um,'[um]'));
saveas(gca,'output.png');

json.FM.imageSize_pix = size(flourescenceIm);

%% Check that slide naming is found in the histology instructions
slideName = sprintf('Slide%02d_Section%02d',slideNumber,sectionNumber);
ii = cellfun(@(x)strcmp(x,slideName),sectionNames);
if sum(ii)~=1 
    %Can't find this section name
    error('Slide Name "%s" is not in the list of section names in the histology instructions. Or that name was present before',slideName);
end
sectionNames(ii==1) = []; %Remove this section name so it won't be repeated

%% Save Output
fprintf('%s Uploading output..\n',datetime)
outputFolder = awsModifyPathForCompetability(sprintf('%s/Slides/%s/',s3Dir,slideName));
json.photobleachedLinesImagePath = 'FM_PhotobleachedLinesImage.tif';
imwrite(flourescenceIm,json.photobleachedLinesImagePath);

if ~isempty(brightfieldImagePath)
    json.brightFieldImagePath = 'FM_BrightfieldImage.tif';
    imwrite(brightfieldIm,json.brightFieldImagePath);
else
    json.brightFieldImagePath = '';
end
if ~isempty(beadsImagePath)
    json.beadsImagePath = 'FM_BeadsImage.tif';
    imwrite(beadsIm,json.beadsImagePath);
else
    json.beadsImagePath = '';
end

if awsExist([outputFolder '/' json.photobleachedLinesImagePath],'file')
    error('%s already exist, will not upload again.', ...
        [outputFolder '/' json.photobleachedLinesImagePath]);
end

awsWriteJSON(json,[outputFolder '/SlideConfig.json']);
awsCopyFileFolder(json.photobleachedLinesImagePath,outputFolder);

if ~isempty(brightfieldImagePath)
    awsCopyFileFolder(json.brightFieldImagePath,outputFolder);
end
if ~isempty(beadsImagePath)
    awsCopyFileFolder(json.beadsImagePath,outputFolder);
end

ds = fileDatastore(folder,'ReadFcn',@(x)(x),'IncludeSubfolders',true);
files = ds.Files;
toSend = cellfun(@(x)(contains(x,fileName)),files);
files = files(toSend);
for i=1:length(files)
    awsCopyFileFolder(files{i},[outputFolder '/FM_Raw/']);
end

fprintf('%s Uploading complete.\n',datetime)
end