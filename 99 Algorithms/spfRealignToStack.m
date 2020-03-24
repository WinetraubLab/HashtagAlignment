function spfOut = spfRealignToStack(varargin)
% This function takes a Single Plane Fit (spf) and realign it as best as it
% can to the stack average parameters: normal, and single pixel size.
% At the output of the process, spfOut will have the same normal as the
% stack and same pixel size.
%
% USAGE (1): Use one of these to realign an existing plane.
%   spfOut = spfRealignToStack (spfIn, stackNormal, planeDistance, stackSizeChange_p, pixelSize_um)
%   spfOut = spfRealignToStack (u,v,h, stackNormal, planeDistance, stackSizeChange_p, pixelSize_um, v_)
% USAGE (2): If spfIn does not exist, no plane to realign, this generates a
%   plane from scratch.
%   spfOut = spfRealignToStack (stackNormal, planeDistance, sizeChange_p, pixelSize_um)
%
% INPUTS:
%   - Input plane, pfOut will try to be as close as possible to these.
%     options:
%       + spfIn - single plane fit structure.
%       + u,v,h are 3D vectors defining the plane as u*U+v*V+h. units: mm
%       + v_ [optional] - typical value for v (pixels) for the top of the
%         picture, it is used for estimating a top view for spf. If not 
%         defined, will use NaN.
%   - stackNormal - 3D unit vector identifing the direction of the average
%       plane normal.
%   - planeDistance - according to the stack, what is the plane
%       distance(mm) from origin.
%   - Parameters used for computing new pixel size |u|, |v|:
%       + stackSizeChange_p - stack average size change in %. stackSizeChange_p=-50 means
%         shrinkage by 50%
%       + pixelSize_um - fluorescence microscope pixel size.
%     The following relationship holds: pixelSize_um = |u|*(1+stackSizeChange_p/100);
% OUTPUTS:
%   - spfOut - Single Plane Fit data structure.

%% Input checks

if length(varargin) == 5
    spfIn = varargin{1};
    stackNormal = varargin{2};
    planeDistance = varargin{3};
    stackSizeChange_p = varargin{4};
    pixelSize_um = varargin{5};
elseif length(varargin) == 7 || length(varargin) == 8
    u = varargin{1};
    v = varargin{2};
    h = varargin{3};
    stackNormal = varargin{4};
    planeDistance = varargin{5};
    stackSizeChange_p = varargin{6};
    pixelSize_um = varargin{7};
    
    if (length(varargin) == 8)
        v_ = varargin{8};
    else
        v_ = NaN;
    end
    
    spfIn = spfCreateFromUVH(u,v,h,v_,pixelSize_um);
elseif length(varargin) == 3
    u = [1 0 0];
    v = [0 0 1];
    h = [0 0 0];
    stackNormal = varargin{1};
    planeDistance = varargin{2};
    stackSizeChange_p = varargin{3};
    pixelSize_um = varargin{4};
    
    spfIn = spfCreateFromUVH(u,v,h,NaN,pixelSize_um); 
else
    error('Wrong number of inputs, see function documentation');
end

%% Project SPF to the stack average
project = @(vect)(vect - dot(vect,stackNormal)*stackNormal);
uNormStack_mm = pixelSize_um*1e-3/(stackSizeChange_p/100+1);

% Project u,v to the new plane, correct them to preserve norm, notice that
% u and v might not be prepandicular to each other after projection
u = project(spfIn.u);
v = project(spfIn.v);
u = u/norm(u);
v = v/norm(v);

% Make sure u,v are prepandicular. let us define U,V as prepandicualr
% versions of u,v. U*V = 0. U = u + a/2*(u-v), V = v - a/2(u-v).
% Run it a few times for convergance
for i=1:2
    a = dot(u,v)/(1-dot(u,v));
    u = u + a/2*(u-v); u = u/norm(u);
    v = v - a/2*(u-v); v = v/norm(v);
end

% Set pixel size change.
u = u*uNormStack_mm/norm(u);
v = v*uNormStack_mm/norm(v);

% For h, replace the component prepandicular to the palne with the
% corrected component
h = project(spfIn.h) + stackNormal*planeDistance;

%% Compute spfOut
% Generate a new structure
spfOut = spfCreateFromUVH(u,v,h,spfIn.vTypical,pixelSize_um);

% Make sure d is specified, its important
if (isnan(spfOut.d))
    spfOut.d = planeDistance;
end