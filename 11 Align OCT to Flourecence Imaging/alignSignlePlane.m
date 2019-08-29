function singlePlaneFit = alignSignlePlane(f,pixelSize_um)
%This function computes a single plane fit using Fiducial Lines.
%INPUTS:
%   f - Fiducial lines structure array
%   pixelSize_um - optional, pixel size at the Flourecent Image - this will
%       allow us to cmpute % shrinkage
%   single plane contains singlePlane.u, .v, .h and some statistics about the
%   plane

gr = [f.group];
if (sum(gr == 'v') < 2) || (sum(gr == 'h') < 2)
    singlePlaneFit = NaN;
    return; %Failed to align
end

%% Compute fit
[u,v,h] = fdlnEstimateUVHSinglePlane(f); %u,v,h in mm

singlePlaneFit.u = u;
singlePlaneFit.v = v;
singlePlaneFit.h = h;

n = cross(u/norm(u),v/norm(v)); %Compute norm vector to the plane

%% Notes
singlePlaneFit.notes = sprintf([...
    'tilt_deg - angle between plane norm and z axis [deg] \n' ...
    'rotation_deg - rotation angle about the z axis (on the x-y plane) [deg] \n' ...
    'distanceFromOrigin_mm - distance between origin (0,0,0) to the plane [mm]\n' ...
    'sizeChange_precent - if negative value, isotropic shrinkage of the histology compared to OCT. If positive, expansino [%%]\n' ...
...    'xPlaneUFunc_pix - This describes the projection of the plane x=c on to the histology section the fuction recives v [pix] and c and returns u_pix\n' ...
...    'yPlaneUFunc_pix - This describes the projection of the plane y=c on to the histology section the fuction recives v [pix] and c and returns u_pix\n' ...
...    'zPlaneVFunc_pix - This describes the projection of the plane z=c on to the histology section the fuction recives u [pix] and c and returns v_pix\n' ...
    'xIntercept_mm - (x,y) position of where histology plane hits x=0 plane (average position) [mm]\n' ...
    'yIntercept_mm - (x,y) position of where histology plane hits y=0 plane (average position) [mm]\n' ...
    ]);

%% Compute general gemoetry
tilt = asin(n(3))*180/pi; %[deg]
rotation = atan2(-n(2),n(1))*180/pi; %[orientation]
dFromOrigin = dot(h,n);

if exist('pixelSize_um','var')
    sizeChange = 100*(( pixelSize_um / ((norm(u)+norm(v))/2*1e3)  )-1); 
else
    sizeChange = NaN;
end

singlePlaneFit.tilt_deg = tilt;
singlePlaneFit.rotation_deg = rotation;
singlePlaneFit.distanceFromOrigin_mm = dFromOrigin;
singlePlaneFit.sizeChange_precent = sizeChange;

%% Cross sections projections
%Compute x & y intercept and how should they appear in the image

xPlaneUFunc_pix = @(vint,c)(-v(1)/u(1)*vint-h(1)/u(1)+c/u(1)); %x=c
yPlaneUFunc_pix = @(vint,c)(-v(2)/u(2)*vint-h(2)/u(2)+c/u(2)); %y=c
zPlaneVFunc_pix = @(uint,c)(-u(3)/v(3)*uint-h(3)/v(3)+c/v(3)); %z=c

%singlePlaneFit.xPlaneUFunc_pix = xPlaneUFunc_pix;
%singlePlaneFit.yPlaneUFunc_pix = yPlaneUFunc_pix;
%singlePlaneFit.zPlaneVFunc_pix = zPlaneVFunc_pix;

%0 intercepts
vspan = [min(min([f.v_pix])) max(max([f.v_pix]))];
yOfYIntercept = xPlaneUFunc_pix(mean(vspan),0)*u(2)+mean(vspan)*v(2)+h(2);
xOfXIntercept = yPlaneUFunc_pix(mean(vspan),0)*u(1)+mean(vspan)*v(1)+h(1);
singlePlaneFit.xIntercept_mm = [xOfXIntercept 0];
singlePlaneFit.yIntercept_mm = [0 yOfYIntercept];

