function [tform, isHistImageFlipped] = HistFM_xcorr(imFM, imPB, imHist)
%This uses normalized cross correlation to align the input
%the histology slices with input flourecence microscopy images
%
%It finds the correct rotation, translation, and horiztonal flip which
%maximizes the normalized cross correlation.
% 
%It assumes that there is a known scaling factor between the images (0.7 
%below), and then performs coarse registration (translation accuracy: 
%16 pixels, rotational accuracy: 1 degree) and then fine registration  
%(translation accuracy: 1 pixels, rotational accuracy: 0.1 degree).
%
%INPUTS:
% - imFM - SP5 brighfield image
% - imPB - SP5 630 excitation fluorescence image
%   imHist - 20x Histology image
%OUTPUTS:
% - tform
% - isHistImageFlipped

pxielSize_FM = 0.720915041080197;
pixelSize_Histology = 0.503661377589388;
SP52Hist_scale = pixelSize_Histology / pxielSize_FM;
he_background = 20;

%% Section 0 - read imgs
% read he images
he0 = imHist;

% set black artifact in HE scan to background level
M = repmat(all(~he0,3),[1 1 3]); %mask black parts
he0(M) = 255 - he_background; %turn them white

he0 = imresize(he0, SP52Hist_scale);
he = he0;
he = mean(he,3);

% normalize he image
he = 255 - he;
he = he-he_background;
he(he<0) = 0;

he_new = he;
he_new_fliplr = fliplr(he);

% read SP5 images
bf0 = imFM;
fl0 = imPB;
bf0(isnan(bf0)) = 255;
fl0(isnan(fl0)) = 0;

% find background level of brightfiled images using fluorescence image
% assumes that fluorescent image has gel facing towards top of image
mask = imfill(medfilt2(fl0,[4,4])> prctile(fl0(:),80),'holes');
CC = bwconncomp(mask);
numPixels = cellfun(@numel,CC.PixelIdxList);
[~,idx] = max(numPixels);
iTemp = zeros(size(fl0,1), size(fl0,2));
iTemp(CC.PixelIdxList{idx})=1;
mask = iTemp;

background_mask = zeros(size(mask));
for j=1:size(mask,2)
    line = mask(:,j);
    ind = find(line>0);

    if ~isempty(ind)
        background_mask(1:ind(1),j) = 1;
    end
end

% lower background  by 0.6 factor to ensure removal - leads to more robust
% results
background = 0.6*mean(mean(bf0(logical(background_mask)),1),2);

% normalize bf image
bf = double(bf0)*255/background;
bf(bf>255) = 255;
bf = 255- bf;

% place bf image in 0 padded image of same size as HE image
xind = round(size(he_new,2)/2) - round(size(bf,2)/2) + [1:size(bf,2)];
yind = round(size(he_new,1)/2) - round(size(bf,1)/2)+ [1:size(bf,1)];

bf_new = zeros(size(he_new));
bf_new0 = zeros(size(he_new));
try % Add a try catch because we are getting an error on this line but not sure why, after we get an answer we can remove catch clause
    bf_new(yind,xind) = bf;
catch e
    disp('Here are varibles that might help troubleshoot:');
    yind
    xind
    rethrow(e);
end
bf_new0(yind,xind) = bf0;
%% Section 1 - coarse registration

% scale down images for coarse registration
downscale = 1/16;

he_new2 = imresize(he_new,downscale);
he_new2_fliplr = imresize(he_new_fliplr,downscale);
bf_new2 = imresize(double(bf_new),downscale);

% normalized cross-correlation over all angles and flipped and not flipped
% orientations (takes 5 minutes)
angles = [0:1:360];
for rot_i = 1:length(angles)
    
    a = he_new2;
    b = imrotate(bf_new2,angles(rot_i),'crop');
    
    C(:,:,rot_i) = normxcorr2(a,b);
end
[xcorr_val,ind]=max(C,[],'all','linear');

for rot_i = 1:length(angles)
    
    a = he_new2_fliplr;
    b = imrotate(bf_new2,angles(rot_i),'crop');
    
    C_fliplr(:,:,rot_i) = normxcorr2(a,b);
end
[xcorr_val_fliplr,ind_fliplr]=max(C_fliplr,[],'all','linear');

isHistImageFlipped = xcorr_val_fliplr > xcorr_val;

% calculate coarse registration offsets and angle
if isHistImageFlipped
    he_fine = he_new2_fliplr;
    [peaky,peakx,peakr] = ind2sub(size(C_fliplr),ind_fliplr);
else
    he_fine = he_new2;
    [peaky,peakx,peakr] = ind2sub(size(C),ind);
end

offsety_c = peaky - size(he_new2,1);
offsetx_c = peakx - size(he_new2,2);
rot_angle_c = angles(peakr);

% for debugging
%figure; imagesc(imfuse(imtranslate(imrotate(bf_new2,rot_angle_c ,'crop'),[-offsetx_c,-offsety_c]),he_fine));
%% fine registration
upsample = 1;

% created cropped images for fine registration
crop_bf = bf;
% only  approximate translation because he has a slightly different center from bf
if isHistImageFlipped
    crop_he = imtranslate(imrotate(fliplr(he),-rot_angle_c ,'crop'),[offsetx_c*1/downscale,offsety_c*1/downscale]);
else
    crop_he = imtranslate(imrotate(he,-rot_angle_c ,'crop'),[offsetx_c*1/downscale,offsety_c*1/downscale]);
end

crop_he = crop_he(yind,xind);
he_pad = 50;
crop_he = padarray(crop_he,[he_pad,he_pad]);

crop_bf = imresize(crop_bf,upsample);
crop_he = imresize(crop_he,upsample);

% perform fine registration
angles_fine = [-0.5:0.1:0.5];

clearvars F
for rot_i = 1:length(angles_fine)
    a=crop_bf;
    b=imrotate(crop_he,angles_fine(rot_i),'crop');
    F(:,:,rot_i) = normxcorr2(a,b);
end

% calculate resulting offsets and angle
[~,ind]=max(F,[],'all','linear');
[peaky,peakx,peakr] = ind2sub(size(F),ind);
offsety = peaky - size(crop_bf,1);
offsetx = peakx - size(crop_bf,2);
rot_angle = angles_fine(peakr);

% calculate the final HE image corresponding to input BF
if isHistImageFlipped
    he_final =  imtranslate(imrotate(fliplr(he0),-rot_angle_c,'crop'),[offsetx_c*1/downscale,offsety_c*1/downscale]);
else
    he_final =  imtranslate(imrotate(he0,-rot_angle_c,'crop'),[offsetx_c*1/downscale,offsety_c*1/downscale]);
end
he_final = he_final(yind(1)-he_pad:yind(end)+he_pad,xind(1)-he_pad:xind(end)+he_pad,:);
he_final = imtranslate(imrotate(he_final,rot_angle,'crop'),[-offsetx*1/upsample,-offsety*1/upsample]);
he_final = he_final(1:size(bf0,1),1:size(bf0,2),:);

%% find corrresponding tform
if isHistImageFlipped
    original = uint8(mean(fliplr(imHist),3));
else
    original = uint8(mean(imHist,3));
end
distorted = uint8(mean(he_final,3));

% detect and extact features
ptsOriginal  = detectSURFFeatures(original);
ptsDistorted = detectSURFFeatures(distorted);
[featuresOriginal,validPtsOriginal] = ...
    extractFeatures(original,ptsOriginal);
[featuresDistorted,validPtsDistorted] = ...
    extractFeatures(distorted,ptsDistorted);

% match points
index_pairs = matchFeatures(featuresOriginal,featuresDistorted);
matchedPtsOriginal  = validPtsOriginal(index_pairs(:,1));
matchedPtsDistorted = validPtsDistorted(index_pairs(:,2));

% calculate tform
[tform,~,~] = ...
    estimateGeometricTransform(matchedPtsOriginal,matchedPtsDistorted,...
    'similarity');