function im_pd = imPadToMeetPatchSize (im, minPatchSize, padValue)

h=size(im,1); 
w=size(im,2);

im_pd = ones(...
    max(h,minPatchSize+1),...
    max(w,minPatchSize+1),...
    size(im,3),'uint8')*padValue;
im_pd(1:h,1:w,:) = im;