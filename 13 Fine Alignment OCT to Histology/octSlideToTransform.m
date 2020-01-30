function histologyToOCTT = octSlideToTransform(...
    umm,vmm,hmm,new2OriginalAffineTransform,topLeftCornerXmm,topLeftCornerZmm,scale_umperpix,octScale_umperpix)
% Using slide data, what is the appropriate 2d transform.
% INPUTS:
%   u,v,h of the slide (in milimiters)
%   new2OriginalAffineTransform - from OCT Reslice iteration, what is the
%       affine transform from new (resliced) coordinate system to original
%       OCT scan.
%   topLeftCornerXmm, topLeftCornerZmm - top left corner position in new
%       resliced coordinate system of the resliced volume. This point is
%       corresponding to 'h', the origin of the histology image.
%   scale_umperpix - from the stack average.
%   octScale_umperpix - stack OCT scale (microns per pixel).


% Step #1, express u,v,h in the new, resliced coordiate system
u_R = new2OriginalAffineTransform(1:3,1:3)^-1*umm(:);
v_R = new2OriginalAffineTransform(1:3,1:3)^-1*vmm(:);
h_R = new2OriginalAffineTransform(1:3,1:3)^-1*hmm(:);

% Step #2, project u,v,h to the resliced 2D plane (y direction is
%   projected)
u_2D = [u_R(1) u_R(3)]';
v_2D = [v_R(1) v_R(3)]';
h_2D = [h_R(1) h_R(3)]';

% Compute translation
xTranslation_um = (h_2D(1) - topLeftCornerXmm)*1e3;
zTranslation_um = (h_2D(2) - topLeftCornerZmm)*1e3;

% Compute rotation
rotation_deg = 180/pi * atan2(u_2D(2),u_2D(1));

% Finally, compute transform.
histologyToOCTT = knobesToTransform( ...
    scale_umperpix,rotation_deg,xTranslation_um,zTranslation_um, octScale_umperpix);
