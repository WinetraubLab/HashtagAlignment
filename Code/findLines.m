function lineCenters = findLines (img,v)
%This function takes image img, and outputs line centers
%USAGE:
%   lineCenters = findLines (img [,v])
%INPUTS:
%   img - gray scale flourecence image
%   v - verbos mode [default: false]
%OUTPUTS:
%   lineCenters - format?
%EXAMPLE:
%   findLines(imread('filepth'),true);

if ~exists(v,'var')
    v = false;
end

%Code...


if (v)
   %Plotting 
end

