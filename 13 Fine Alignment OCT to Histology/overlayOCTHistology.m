function [imOCTOut,imHistologyOut] = overlayOCTHistology(imOCT,imHistology,histologyToOCTT,...
    isMoveHistologyToAlignWithOCT)
% imOCT - OCT slide
% imHistology - Histology slide
% histologyToOCTT - affine transform
% isMoveHistologyToAlignWithOCT - set to true of you would like to move
%   histology to OCT false to move oct to histology

%imOCT = mat2gray(imOCT);

if isMoveHistologyToAlignWithOCT
    imOCTOut = imOCT; % No movement
    
    ref = imref2d([size(imOCT,1), size(imOCT,2), 3]);
    imHistologyOut = imwarp(imHistology,...
        affine2d(histologyToOCTT),'OutputView',ref);
else
    imHistologyOut = imHistology;
    
    ref = imref2d([size(imHistology,1), size(imHistology,2), 1]);
    imOCTOut = imwarp(imOCT,...
        invert(affine2d(histologyToOCTT)),'OutputView',ref);
end

%image(imfuse(imOCTOut,imHistologyOut));