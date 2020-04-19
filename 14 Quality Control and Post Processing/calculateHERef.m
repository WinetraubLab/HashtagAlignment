function [HERef] = calculateHERef(I)
% Calculates H&E color vectors (HERef) for the input image I
%
% Input:
% I         - RGB input image, to calculate HERef for;
% 
% Function variables:
% Io        - (optional) transmitted light intensity (default: 240);
% beta      - (optional) OD threshold for transparent pixels (default: 0.15);
% alpha     - (optional) tolerance for the pseudo-min and pseudo-max (default: 1);
% maxCRef   - (optional) reference maximum stain concentrations for H&E (default value is defined);
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
if ~exist('beta', 'var') || isempty(beta)
    beta = 0.1;
end

% tolerance for the pseudo-min and pseudo-max
if ~exist('alpha', 'var') || isempty(alpha)
    alpha = 1;
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
ODhat = OD(~(all(OD < beta, 2) | all(OD > 1.2, 2)), :);
OD((all(OD < beta, 2) | all(OD > 1.2, 2)), :) = 0;
   
% calculate eigenvectors
[V, ~] = eig(cov(ODhat));

% project on the plane spanned by the eigenvectors corresponding to the two
% largest eigenvalues
That = ODhat*V(:,2:3);

% find the min and max vectors and project back to OD space
phi = atan2(That(:,2), That(:,1));

minPhi = prctile(phi, alpha);
maxPhi = prctile(phi, 100-alpha);

vMin = V(:,2:3)*[cos(minPhi); sin(minPhi)];
vMax = V(:,2:3)*[cos(maxPhi); sin(maxPhi)];

% a heuristic to make the vector corresponding to hematoxylin first and the
% one corresponding to eosin second
if vMin(1) > vMax(1)
    HERef = [vMin vMax];
else
    HERef = [vMax vMin];
end

end
