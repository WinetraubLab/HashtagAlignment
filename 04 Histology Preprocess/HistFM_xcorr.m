function [tform, isHistImageFlipped] = HistFM_xcorr(imFM, imPB, imHist)
%This uses the input MATLAB one-plus-one evolutionary optimizer 
%configuration and rigid transformations (rotation and translation) to 
%align the input histology slices with input flourecence microscopy images
%
%It finds the correct rotation and translation which maximizes the Mattes 
%mutual information metric. It chooses the horizontal flip based on the 
%maximum of the normalized cross correlation between the registered
%(flipped and non-flipped) histology slice and the flourecence microscopy 
%images.
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

%% Image Pre-Processing Steps
pxielSize_FM = 0.720915041080197;
pixelSize_Histology = 0.503661377589388;
SP52Hist_scale = pixelSize_Histology / pxielSize_FM;
he_background = 20;

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

%% Downscaled Registration
[optimizer,metric] = imregconfig('multimodal');

% Apply histogram equalization. This step helps improve registration
% accuracy
he_new_hist_eq = histeq(he_new);
he_new_fliplr1_hist_eq = histeq(he_new_fliplr);
bf1_hist_eq = histeq(bf);

% Scale down the images 
downscale = 1/8;
he_new_downscaled = imresize(he_new_hist_eq, downscale);
he_new_fliplr_downscaled = imresize(he_new_fliplr1_hist_eq, downscale);
bf_downscaled = imresize(bf1_hist_eq, downscale);

tform_fliplr = imregtform(he_new_fliplr_downscaled,bf_downscaled,'rigid',optimizer,metric);
tform_normal = imregtform(he_new_downscaled,bf_downscaled,'rigid',optimizer,metric);

% Fix Translation Factor Due to Downscaling
tform_fliplr.T(3,1) = tform_fliplr.T(3,1) * 8;
tform_fliplr.T(3,2) = tform_fliplr.T(3,2) * 8;

tform_normal.T(3,1) = tform_normal.T(3,1) * 8;
tform_normal.T(3,2) = tform_normal.T(3,2) * 8;

% Debug Plotting
%Rfixed = imref2d(size(bf));
%he_new_fliplr_registered = imwarp(he_new_fliplr,tform_fliplr, 'OutputView', Rfixed);
%he_new_registered = imwarp(he_new,tform_normal, 'OutputView', Rfixed);
%figure();imshowpair(he_new_fliplr_registered, bf);title("Flipped Registration");
%figure();imshowpair(he_new_registered, bf);title("Un-Flipped Registration");

%% Apply registration to histology image
Rfixed_downscaled = imref2d(size(bf_downscaled));
he_new_fliplr_reg_downscaled = imwarp(imresize(he_new_fliplr, downscale),tform_fliplr,'OutputView',Rfixed_downscaled);
he_new_reg_downscaled = imwarp(imresize(he_new, downscale),tform_normal,'OutputView',Rfixed_downscaled);

%% Determine flip orientation 
flipC = normxcorr2(he_new_fliplr_reg_downscaled, bf_downscaled);
C = normxcorr2(he_new_reg_downscaled, bf_downscaled);

[xcorr_val,ind]=max(C,[],'all','linear');
[xcorr_val_fliplr,ind_fliplr]=max(flipC,[],'all','linear');

if xcorr_val_fliplr > xcorr_val
    tform = tform_fliplr;
    isHistImageFlipped = true;
else
    tform = tform_normal;
    isHistImageFlipped = false;
end

