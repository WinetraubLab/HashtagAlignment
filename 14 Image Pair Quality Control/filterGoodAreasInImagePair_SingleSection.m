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

 % Compute intensity with depth. keep signal around the pick (which is the
% interface of tissue).
m = medfilt2(imOCT,[50,20]); % median filter to get rid of gel interface and smooth horizontally

m_reduced = m(~all(isnan(m),2),:); % remove rows that are all nan
m(:,any(isnan(m_reduced),1)) = nan; % remove column if any elments are nan
[~,ind] = max(m,[],'omitnan'); % find max of each column

% if reduced image 'm' is less than 100 pixels wide, revert to
% using axis2 mean of image instead (for example, if image is triangular shape)
if sum(ind ~= 1)>100
    ind(ind == 1) = size(m,1);    % if the max was 1 (the column was all nan's) set to image height
    ind = medfilt1(ind,150,'omitnan','truncate'); % median filter again to remove outliers
    interfaceI = min(ind);
else
    m = nanmean(medfilt2(imOCT,[50,20]),2);
    interfaceI = find(m>0,1,'first'); %find first index greater than signal = 0
end

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
low_sig_mask = logical(zeros(size(low_sig_mask)));
low_sig_mask(CC.PixelIdxList{indexOfMax}) = 1;

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
awsCopyFileFolder('tmp.png',[subjectPath '/Log/14 Image Pair Quality Control/' sectionName '.png']);
delete tmp.png

slideConfig.alignedImagePath_Mask = 'MaskAligned.tif';
slideConfig.alignedImagePath_MaskLegend = maskLegend;

yOCT2Tif(mask,[sectionPath slideConfig.alignedImagePath_Mask],'metadata',aux);
awsWriteJSON(slideConfig,slideConfigPath);
