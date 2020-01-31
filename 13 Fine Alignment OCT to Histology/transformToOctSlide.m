function [u,v,h] = transformToOctSlide(...
    histologyToOCTT,new2OriginalAffineTransform,topLeftCornerXmm,topLeftCornerZmm,octScale_umperpix, planeDistanceFromOrigin_mm)
% Using 2 transformation, what is the single plane fit of the slide
% INPUTS:
%   histologyToOCTT - 2D Transformation matrix
%   new2OriginalAffineTransform - from OCT Reslice iteration, what is the
%       affine transform from new (resliced) coordinate system to original
%       OCT scan.
%   topLeftCornerXmm, topLeftCornerZmm - top left corner position in new
%       resliced coordinate system of the resliced volume. This point is
%       corresponding to 'h', the origin of the histology image.
%   octScale_umperpix - stack OCT scale (microns per pixel).
%   planeDistanceFromOrigin_mm - distance along resliced y direction.
%OUPTUS:
%   u,v,h in mm at the original OCT coordinate system (not the relsliced!)

%% Step #1, u,v,h in the resliced coordinate system
tmp = [1 0 1]*histologyToOCTT - [0 0 1]*histologyToOCTT;
u_R = [tmp(1) 0 tmp(2)]'*octScale_umperpix*1e-3;
tmp = [0 1 1]*histologyToOCTT - [0 0 1]*histologyToOCTT;
v_R = [tmp(1) 0 tmp(2)]'*octScale_umperpix*1e-3;

tmp = [0 0 1]*histologyToOCTT;
tmp = tmp*octScale_umperpix*1e-3;
h_R = [...
    tmp(1)+topLeftCornerXmm ...
    planeDistanceFromOrigin_mm ...
    tmp(2)+topLeftCornerZmm]';

%% Step #2, express u,v,h in the original coordiate sysetm
u = new2OriginalAffineTransform(1:3,1:3)*u_R(:);
v = new2OriginalAffineTransform(1:3,1:3)*v_R(:);
h = new2OriginalAffineTransform(1:3,1:3)*h_R(:);
