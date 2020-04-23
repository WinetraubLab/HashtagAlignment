function [Inorm, H, E] = normalizeStaining(I)
% Normalize the staining appearance of images originating from H&E stained
% sections.
%
% Input:
% I         - RGB input image, to be normalized;
% 
% Function variables:
% Io        - (optional) transmitted light intensity (default: 240);
% beta      - (optional) OD threshold for transparent pixels (default: 0.15);
% alpha     - (optional) tolerance for the pseudo-min and pseudo-max (default: 1);
% maxCRef   - (optional) reference maximum stain concentrations for H&E (default value is defined);
% HERef     - reference H&E OD matrix, taken from LD-06 with manual modifications;
%             Defined below on line 57.
%
% Output:
% Inorm     - normalized image;
% H         - (optional) hematoxylin image;
% E         - (optional)eosin image;
%
% References:
% A method for normalizing histology slides for quantitative analysis. M.
% Macenko et al., ISBI 2009
%
% Efficient nucleus detector in histopathology images. J.P. Vink et al., J
% Microscopy, 2013
%
% Github Repository:
% https://github.com/mitkovetta/staining-normalization
%
% Copyright (c) 2013, Mitko Veta
% Image Sciences Institute
% University Medical Center
% Utrecht, The Netherlands
% with modifications by E. Yuan
% 
% See the license.txt file for copying permission.
%

% transmitted light intensity
if ~exist('Io', 'var') || isempty(Io)
    Io = 240;
end

% OD threshold for transparent pixels
if ~exist('beta1', 'var') || isempty(beta1)
    beta1 = 0.1;
end

% tolerance for the pseudo-min and pseudo-max
if ~exist('alpha1', 'var') || isempty(alpha1)
    alpha1 = 1;
end

% reference H&E OD matrix
if ~exist('HERef', 'var') || isempty(HERef)
	% Use calculateHERef function to compute this reference re-coloring vector
    HERef =  [0.759569358860349,-0.322561704422584307;
         0.942831210850856,0.739522098490852;
         0.267537650874669,0.137850718311857];
end

% reference maximum stain concentrations for H&E
if ~exist('maxCRef)', 'var') || isempty(maxCRef)
    maxCRef = [
        1.9705
        1.0308
        ];
end

h = size(I,1);
w = size(I,2);

I = double(I);

I = reshape(I, [], 3);

% calculate optical density
OD = -log((I+1)/Io);

% remove transparent pixels
% remove all dark pixels in original image
ODhat = OD(~(all(OD < beta1, 2) | all(OD > 1.2, 2)), :);
OD((all(OD < beta1, 2) | all(OD > 1.2, 2)), :) = 0;
   
% calculate eigenvectors
[V, ~] = eig(cov(ODhat));

% project on the plane spanned by the eigenvectors corresponding to the two
% largest eigenvalues
That = ODhat*V(:,2:3);

% find the min and max vectors and project back to OD space
phi = atan2(That(:,2), That(:,1));

minPhi = prctile(phi, alpha1);
maxPhi = prctile(phi, 100-alpha1);

vMin = V(:,2:3)*[cos(minPhi); sin(minPhi)];
vMax = V(:,2:3)*[cos(maxPhi); sin(maxPhi)];

% a heuristic to make the vector corresponding to hematoxylin first and the
% one corresponding to eosin second
if vMin(1) > vMax(1)
    HE = [vMin vMax];
else
    HE = [vMax vMin];
end

% rows correspond to channels (RGB), columns to OD values
Y = reshape(OD, [], 3)';

% determine concentrations of the individual stains
C = HE \ Y;

% normalize stain concentrations
maxC = prctile(C, 99, 2);

C = bsxfun(@rdivide, C, maxC);
C = bsxfun(@times, C, maxCRef);

% recreate the image using reference mixing matrix
Inorm = Io*exp(-HERef * C);
Inorm = reshape(Inorm', h, w, 3);
Inorm = uint8(Inorm);

if nargout > 1
    H = Io*exp(-HERef(:,1) * C(1,:));
    H = reshape(H', h, w, 3);
    H = uint8(H);
end

if nargout > 2
    E = Io*exp(-HERef(:,2) * C(2,:));
    E = reshape(E', h, w, 3);
    E = uint8(E);
end

end
