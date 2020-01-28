function singlePlaneFit = spfCreateFromFiducialLines(f,pixelSize_um)
%This function computes a single plane fit using Fiducial Lines.
%INPUTS:
%   f - Fiducial lines structure array
%   pixelSize_um - optional, pixel size at the Flourecent Image - this will
%       allow us to cmpute % shrinkage

%% Input checks
gr = [f.group];
if (sum(gr == 'v') < 2) || (sum(gr == 'h') < 2)
    singlePlaneFit = NaN;
    return; %Failed to align
end

if ~exist('pixelSize_um','var')
    pixelSize_um = NaN;
end

%% Typical values
vspan = [min(cellfun(@min,{f.v_pix})) max(cellfun(@max,{f.v_pix}))];
v_ = mean(vspan);

%% Compute fit & create fiducial line structure
[u,v,h] = fdlnEstimateUVHSinglePlane(f); %u,v,h in mm
singlePlaneFit = spfCreateFromUVH(u,v,h,v_,pixelSize_um);

%% Compute Fit Score, lower is better
xPlaneUFunc_pix = @(vint,c)(-v(1)/u(1)*vint-h(1)/u(1)+c/u(1)); %x=c
yPlaneUFunc_pix = @(vint,c)(-v(2)/u(2)*vint-h(2)/u(2)+c/u(2)); %y=c
zPlaneVFunc_pix = @(uint,c)(-u(3)/v(3)*uint-h(3)/v(3)+c/v(3)); %z=c

scores = zeros(size(f));
for i=1:length(f)
    ff = f(i);
    switch(ff.group)
        case 'v'
            scores(i) = sqrt(mean( (ff.u_pix-xPlaneUFunc_pix(ff.v_pix,ff.linePosition_mm) ).^2 ));
        case 'h'
            scores(i) = sqrt(mean( (ff.u_pix-yPlaneUFunc_pix(ff.v_pix,ff.linePosition_mm) ).^2 ));
        otherwise
            scores(i) = NaN;
    end
end
singlePlaneFit.fitScore = scores(:);

%% Append notes
singlePlaneFit.notes = sprintf(['%s' ...
    'fitScore - lower is better, distance between photobleached feducial lines to the approximation [pix]\n' ...
    ],singlePlaneFit.notes);
