function img = scale0To255(img)
%This function converts a float number to a scale between 0 to 255.
%0 is reserved for nan.

lowerbound = min(img(:));
upperbound = max(img(:));

img(img>upperbound) = upperbound;
img(img<lowerbound) = lowerbound;

img = img - lowerbound;
img = img/(upperbound - lowerbound);
img = uint8(img*254+1);

img = uint8(img);