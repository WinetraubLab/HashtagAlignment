function um = magnificationToPixelSizeMicrons (magnification)
% This function converts from magnification to pixel size
% magnification can be '10x','4x','2x' etc

% See https://www.microscopyu.com/tutorials/matching-camera-to-microscope-resolution
switch(lower(magnification))
    case '10x'
        um = 1;
    case '4x'
        um = 2;
    case '2x'
        um = 4;
    otherwise
        error('magnificationName: %s unknown',magnification);
end