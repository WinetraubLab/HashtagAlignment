%This code allows for the manual segmentation of images into
%cancerous/non-cancerous regions
%INPUT – cancerous sample

original = awsimread('directory goes in here');
imshow(imread(file))
%user draws cancerous region of interest on sample
h = drawfreehand;
h.FaceAlpha = 1;
h.FaceSelectable = false;
MaskCancerAligned = createMask(h);

%displays image of only the cancerous regions + binary mask of cancerous
%regions

maskedRgbImage = bsxfun(@times, original, cast(MaskCancerAligned, 'like', original));
ax1 = subplot(2,2,1);
imshow(maskedRgbImage)
ax2 = subplot(2,2,2);
imshow(MaskCancerAligned)

name = 'MaskCancerAligned.tif';
imwrite(MaskCancerAligned, name)
