function tf = isHistologyToOCTTMakeSense(histologyToOCTT,OCTImageSize, HistologyImageSize)
% This function will try to figure out if OCT image is somewhere in
% histolgoy image, i.e. does it make sense?
% OCTImageSize, HistologyImageSize are size(y), size(x)

% Is any of the corners of OCT inside of the histology image
tl = isOCTPointInsideHistologyImage([1 1], histologyToOCTT, HistologyImageSize);
tr = isOCTPointInsideHistologyImage([1 OCTImageSize(1)], histologyToOCTT, HistologyImageSize);
bl = isOCTPointInsideHistologyImage([OCTImageSize(2) 1], histologyToOCTT, HistologyImageSize);
br = isOCTPointInsideHistologyImage([OCTImageSize(2) OCTImageSize(1)], histologyToOCTT, HistologyImageSize);

tf = (tl + tr + bl + br)>=2; %Many corners should be inside

function tf = isOCTPointInsideHistologyImage(OCTPosPx, histologyToOCTT, HistologyImageSize)
histPosPx = [OCTPosPx(:)' 1]*(histologyToOCTT^-1);
histPosPx = histPosPx(1:2);
tf = all(histPosPx >= 0) & histPosPx(2) < HistologyImageSize(1) & histPosPx(1) < HistologyImageSize(2);