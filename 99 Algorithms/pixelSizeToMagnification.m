function mag = pixelSizeToMagnification(pixelSizeMicrons)
% Opposite of magnificationToPixelSizeMicrons

mags = {'10x','4x','2x'};
pixelSizesUm = [1 2 4];

[~,i] = min(abs(pixelSizeMicrons-pixelSizesUm));
mag = mags{i};