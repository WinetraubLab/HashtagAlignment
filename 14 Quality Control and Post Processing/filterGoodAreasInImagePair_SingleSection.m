% This script goes over the image pairs of aligned OCT and aligned
% histology to try and look for where are the good areas of alignment and
% creates a mask of where we should ignore.

subjectPath = s3SubjectPath('01');
sectionName = 'Slide01_Section01';

% Automation
if exist('subjectPath_','var')
    subjectPath = subjectPath_;
end
if exist('sectionName_','var')
    sectionName = sectionName_;
end

%% Read data
sectionPath = awsModifyPathForCompetability([subjectPath '/Slides/' sectionName '/']);

slideConfigPath = [sectionPath 'SlideConfig.json'];
slideConfig = awsReadJSON(slideConfigPath);

if ~isfield(slideConfig,'alignedImagePath_Histology') || ~isfield(slideConfig,'alignedImagePath_OCT')
    fprintf('Subject %s, section %s doesn''t have aligned OCT & Histology data.\n',s3GetSubjectName(subjectPath),sectionName);
    return;
end

alignedHistologyPath = [sectionPath slideConfig.alignedImagePath_Histology];
alignedOCTPath = [sectionPath slideConfig.alignedImagePath_OCT];

ds = fileDatastore(alignedHistologyPath,'ReadFcn',@imread);
imHist = ds.read();
[imOCT,aux] = yOCTFromTif(alignedOCTPath);

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
x = slideConfig.FM.fiducialLines(1).u_pix;
y = slideConfig.FM.fiducialLines(1).v_pix;
Transform = slideConfig.FMOCTAlignment.FMToOCTTransform;
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
minSignal = -12;
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
    low_sig_mask = logical(zeros(size(low_sig_mask)));
    low_sig_mask(CC.PixelIdxList{indexOfMax}) = 1;
end

mask(low_sig_mask) = 3;

%% Plot Output
x = (1:size(imOCT,2))*slideConfig.FMOCTAlignment.OCTPixelSize_um/1e3; % mm
z = (1:size(imOCT,1))*slideConfig.FMOCTAlignment.OCTPixelSize_um/1e3; % mm

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
      'AlphaData',0.1);
hold off;

%% Upload
saveas(fig1,'tmp.png');
awsCopyFileFolder('tmp.png',[subjectPath '/Log/14 Quality Control and Post Processing/' sectionName '.png']);
delete tmp.png

slideConfig.alignedImagePath_Mask = 'MaskAligned.tif';
slideConfig.alignedImagePath_MaskLegend = maskLegend;

yOCT2Tif(mask,[sectionPath slideConfig.alignedImagePath_Mask],'metadata',aux);
awsWriteJSON(slideConfig,slideConfigPath);
