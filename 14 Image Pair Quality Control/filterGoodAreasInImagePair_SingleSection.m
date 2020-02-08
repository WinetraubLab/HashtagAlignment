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
maskLegend = sprintf('0 - Good Pixel, 1 - Outside or Histology Image, 2 - Far from tissue to interface, 3 - Low Signal');
mask = zeros(size(imOCT));

% No OCT or Histology image data
mask(isnan(imOCT)) = 1;
mask(sum(imHist,3) == 0) = 1;

% Compute intensity with depth. keep signal around the pick (which is the
% interface of tissue).
m = nanmean(imOCT,2);
interfaceI = find(m==max(m),1,'first');
zI = 1:size(mask,1);
outsideArea = zeros(size(mask));
outsideArea(zI<interfaceI - 100 | zI > interfaceI + 400,:) = 1;
mask(outsideArea==1 & mask==0) = 2;

% Low signal
m = double(imOCT);
minSignal = -12;
m(isnan(m)) = minSignal;
m = imgaussfilt(m,20);
mask(m<minSignal ... Under minimal signal
    & repmat(zI(:) > interfaceI,1,size(m,2)) ... Below interface
    & mask==0 ... Not flagged already
    ) = 3;

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
awsCopyFileFolder('tmp.png',[subjectPath '/Log/14 Image Pair Quality Control/' sectionName '.png']);
delete tmp.png

slideConfig.alignedImagePath_Mask = 'MaskAligned.tif';
slideConfig.alignedImagePath_MaskLegend = maskLegend;

yOCT2Tif(mask,[sectionPath slideConfig.alignedImagePath_Mask],'metadata',aux);
awsWriteJSON(slideConfig,slideConfigPath);
