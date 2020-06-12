% This script generates post processed images including OCT slides,
% Histology sections and a mask to highlight good parts from bad ones.

%% Inputs
subjectPath = s3SubjectPath('01');
sectionName = 'Slide03_Section01';

% How many y planes to take around the center OCT plane +-yPlanesAroundCenter
yPlanesAroundCenter = 10; % Each plane is 1um

% Which OCT image would you like to generate mask for:
%   (true) - center of the oct
%   (false) - mean of OCT sections around the center
useOCTSingleSectionToGenerateMask = true;

%% Automation / Json
if exist('subjectPath_','var')
    subjectPath = subjectPath_;
end
if exist('sectionName_','var')
    sectionName = sectionName_;
end

%% Read Configuration Data, read all jsons
jsons = s3LoadAllSubjectSectionJSONs(subjectPath,sectionName);
slideFolder = [fileparts(jsons.slideConfig.path) '/'];

%% OCT Data
jsons.slideConfig.data.alignedImagePath_OCT = 'OCTAligned.tif';
jsons.slideConfig.data.alignedImagePath_OCTStack = 'OCTAligned_Stack.tif';

% Figure out y position of the center image
ys_um = jsons.sectionIterationConfig.data_um.y.values;
d_um = abs(ys_um - ...
    jsons.slideConfig.data.FMOCTAlignment.planeDistanceFromOrigin_mm*1e3 ...
    );
[~,yI] = min(d_um);

yIs = yI + (-yPlanesAroundCenter:yPlanesAroundCenter);
if (min(yIs) < 1)
    error('Section requires a slice that is before the beginning of reslice (min)');
elseif (max(yIs) > length(jsons.sectionIterationConfig.data_um.y.values))
    error('Section requires a slice that is after the last slide of reslice (max)');
end

% Load OCT
octCenterSection = octFromTifCash(jsons.sectionIterationConfig.path,mean(yIs));
octStack = zeros(size(octCenterSection,1),size(octCenterSection,2),length(yIs));
for i=1:length(yIs)
    octStack(:,:,i) = octFromTifCash(jsons.sectionIterationConfig.path,yIs(i));
end

% Save *centeral* section
octMetadata = jsons.sectionIterationConfig.data_um;
octMetadata.y.values = octMetadata.y.values(mean(yIs));
octMetadata.y.index = octMetadata.y.index(mean(yIs));
yOCT2Tif(octCenterSection, ...
    [slideFolder jsons.slideConfig.data.alignedImagePath_OCT], ...
    'metadata', octMetadata);
if (useOCTSingleSectionToGenerateMask)
    imOCT = octCenterSection;
    aux = octMetadata;
end

% Save *stack* around central section
octMetadata = jsons.sectionIterationConfig.data_um;
octMetadata.y.values = octMetadata.y.values(yIs);
octMetadata.y.index = octMetadata.y.index(yIs);
yOCT2Tif(octStack, ...
    [slideFolder jsons.slideConfig.data.alignedImagePath_OCTStack], ...
    'metadata', octMetadata);
if (~useOCTSingleSectionToGenerateMask)
    imOCT = squeeze(mean(octStack,3));
    aux = octMetadata;
end

%% Histology Image
jsons.slideConfig.data.alignedImagePath_Histology = 'HistologyAligned.tif';

histFilePath = awsModifyPathForCompetability(...
    [slideFolder jsons.slideConfig.data.histologyImageFilePath]);
ds = fileDatastore(histFilePath,'ReadFcn',@imread);
imHist = ds.read();

% Explicity set HE0 to be empty if non-existent for whatever reason
if ~exist('HE0','var')
    HE0 = []; % No average HE vector, compute from this slide.
end

% Recolor histology to the standard coloring scheme
imHist = normalizeStaining(imHist,HE0);

% Orient Histology image to OCT reference frame
ref = imref2d([size(imOCT,1), size(imOCT,2), 3]);
imHist = imwarp(imHist,...
    affine2d(jsons.slideConfig.data.FMOCTAlignment.FMToOCTTransform),'OutputView',ref);

% Save histology
imwrite(imHist,'tmp.tif');
awsCopyFileFolder('tmp.tif',[slideFolder jsons.slideConfig.data.alignedImagePath_Histology]);
delete tmp.tif;

%% Generate masks
above_interface = 100;
below_interface = 500; 

maskLegend = sprintf('0 - Good Pixel, 1 - Outside or Histology Image, 2 - Far from tissue to interface, 3 - Low Signal');
mask = zeros(size(imOCT));

% No OCT or Histology image data
mask(isnan(imOCT)) = 1;
mask(sum(imHist,3) == 0) = 1; 

% Begin code to find interface
% extract markedline from json
tissueInterfaceI = [jsons.slideConfig.data.FM.fiducialLines.group] == 't';
x = jsons.slideConfig.data.FM.fiducialLines(tissueInterfaceI).u_pix;
y = jsons.slideConfig.data.FM.fiducialLines(tissueInterfaceI).v_pix;
Transform = jsons.slideConfig.data.FMOCTAlignment.FMToOCTTransform;
ref = imref2d([size(imHist,1), size(imHist,2),1]);

% apply transform of markedline from brightfield to OCT frame 
clearvars X Y
for k=1:length(x)
   temp = ([x(k)  y(k)  1])*Transform;
   X(k) = temp(1);
   Y(k) = temp(2);
end

% interpolate markedline over entire OCT image
X_ = [1:size(imOCT,2)];
[X, index] = unique(X); 
Y_=interp1(X,Y(index),X_);

% cut out markedline over nan regions of OCT image
X = []; Y = [];
for k=1:length(X_)
   try
       if ~isnan(imOCT(round(Y_(k)),round(X_(k))))
           X = [X X_(k)];
           Y = [Y Y_(k)];
       end
   end
end

% interface is min value of markedline
interfaceI = min(Y);
% End code to find interface

% crop out area above interface
zI = 1:size(mask,1);
outsideArea = zeros(size(mask));
outsideArea(zI<interfaceI - above_interface | zI > interfaceI + below_interface,:) = 1;
mask(outsideArea==1 & mask==0) = 2;

% Low signal
m = double(imOCT);
%m(1026:end,623:740) = min(min(m));, used for manually cropping areas out if necessary

% Adaptive threshold for minSignal
m_mean = nanmean(m,2);
m_mean(isnan(m_mean)) = [];
m_mean_max = prctile(m_mean,99);
m_mean_min = mean(m_mean(end-50:end));
minSignal = 0.28 * (m_mean_max - m_mean_min) + m_mean_min;

% Compute log signal mask
m(isnan(m)) = minSignal;
m = imgaussfilt(m,20);
low_sig_mask = (m<minSignal ... Under minimal signal
    & repmat(zI(:) > interfaceI,1,size(m,2)) ... Below interface
    & mask==0 ... Not flagged already
    );

%only take largest connected componenet
CC = bwconncomp(low_sig_mask);
numOfPixels = cellfun(@numel,CC.PixelIdxList);
[unused,indexOfMax] = max(numOfPixels);
if ~isempty(indexOfMax)
    low_sig_mask = zeros(size(low_sig_mask),'logical');
    low_sig_mask(CC.PixelIdxList{indexOfMax}) = 1;
end

mask(low_sig_mask) = 3;
jsons.slideConfig.data.alignedImagePath_Mask = 'MaskAligned.tif';
jsons.slideConfig.data.alignedImagePath_MaskLegend = maskLegend;
yOCT2Tif(mask,[slideFolder jsons.slideConfig.data.alignedImagePath_Mask],'metadata',aux);

%% Plot Output
x = (1:size(imOCT,2))*jsons.slideConfig.data.FMOCTAlignment.OCTPixelSize_um/1e3; % mm
z = (1:size(imOCT,1))*jsons.slideConfig.data.FMOCTAlignment.OCTPixelSize_um/1e3; % mm

m = zeros(length(z),length(x),3);
m(:,:,2) = mask==0;

fig1 = figure(1);
set(fig1,'units','normalized','outerposition',[0 0 1 1]);
subplot(1,1,1);

subplot(1,2,1);
imagesc(x,z,imOCT);
xlabel('x[mm]');
ylabel('z[mm]');
colormap gray;
axis equal;
axis ij;
grid on;
title([ strrep(sectionName,'_','-') ' Area to Use Marked In Green (OCT)']);
hold on;
image('XData',x,'YData',z,...
      'CData',m,...
      'AlphaData',0.1);
hold off;

subplot(1,2,2);
image('XData',x,'YData',z,...
      'CData',imHist);
xlabel('x[mm]');
ylabel('z[mm]');
axis equal;
axis ij;
grid on;
title('Histology');
hold on;
image('XData',x,'YData',z,...
      'CData',m,...
      'AlphaData',0.2);
hold off;

%% Upload drawing and JSON.
awsSaveMatlabFigure(fig1,...
    [subjectPath '/Log/14 Quality Control and Post Processing/' sectionName '.png'],...
    true);

awsWriteJSON(jsons.slideConfig.data,jsons.slideConfig.path);
