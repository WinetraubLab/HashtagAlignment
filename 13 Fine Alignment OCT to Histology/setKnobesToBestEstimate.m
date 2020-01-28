function [x_um, y_um, z_um, scale_umpPerPixel, rot_deg] = setKnobesToBestEstimate(activeSectionIndex,slideConfigJson,stackConfigJson,stackVolumeIterationConfig_um)
% Helper function to set position to the default value
%OUTPUTS:
% - x,y,z - displacement (microns) for the top left corner of the histology
%   image to match to oct resliced
% - rot - rotation (deg) of the histology image to match oct resliced

activeSectionIteration = stackConfigJson.sections.iterations(activeSectionIndex);
%% Set y plane to the bets estimated position according to stack
tmp = arrayfun(@(x)(x.planeDistanceFromOCTOrigin_um(:)'),stackConfigJson.stackAlignment,'UniformOutput',false);
tmp = [tmp{:}];
y_um = round(tmp(activeSectionIndex));

% Set scale to be the real pixel size * Fraction factor mean
scale_umpPerPixel = slideConfigJson.FM.pixelSize_um / ...
    stackConfigJson.stackAlignment(activeSectionIteration).scaleFactor;

%% X-Z-Rotation Guess
if isfield(slideConfigJson.FM,'singlePlaneFit')
    % Get h
    h = slideConfigJson.FM.singlePlaneFit.h;
    if isnan(h(3))
        h(3) = 0;
    end
    
    % Get u,v
    u = slideConfigJson.FM.singlePlaneFit.u;
    u_ = u/norm(u);
    v = slideConfigJson.FM.singlePlaneFit.v;
    v_ = v/norm(v);
    n_ = slideConfigJson.FM.singlePlaneFit.normal;
    % Get the direction in which 
    
    % Coordinate system projection from the original 
    M_OctStack2OriginalVolume = stackVolumeIterationConfig_um.new2OriginalAffineTransform(1:3,1:3);
    M_UVSlide2OriginalVolume = [u_ n_ v_];
    
    % Convert from slide to stack coordinate system
    M_Slide2Stack = M_OctStack2OriginalVolume^-1*M_UVSlide2OriginalVolume;
    rot_deg = asin(M_Slide2Stack(1,3))*180/pi;
    
    hInOctStackCoordinates = M_OctStack2OriginalVolume^-1*h;
    x_um=1e3*hInOctStackCoordinates(1);
    z_um=1e3*hInOctStackCoordinates(3);
else
    %No Guess regarding x,y
end