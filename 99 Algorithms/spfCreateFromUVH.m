function singlePlaneFit = spfCreateFromUVH (u,v,h,v_,pixelSize_um)
%This function creates a single plane fit structure from u,v,h inputs
%Single plane structure contains some statistics on the plane.
%INPUTS: 
%   u,v,h ar 3D vectors defining the plane as u*U+v*V+h. units: mm.
%   v_  [optional] - typical value for v (pixels) for the top of the picture, it is used for
%       estimating a top view for spf. If not defined, will use NaN.
%   pixelSize_um - pixel size of the imaage used by u,v - if exists will
%       compute size change.

if ~exist('v_','var') || isempty(v_)
    v_ = NaN;
end

if ~exist('pixelSize_um','var') || isempty(pixelSize_um)
    pixelSize_um = NaN;
end

%% Notes
singlePlaneFit.notes = sprintf([...
    'u,v,h - plane defenition [mm]\n' ...
    'normal, d - alternative plane defention, n is a unit vector normal to plane (right hand complementry normal (u,-uXv, v), such that any point in the plane p satisfies: n*p-d=0. d in mm\n' ...
    'tilt_deg - angle between plane norm and z axis [deg] \n' ...
    'rotation_deg - rotation angle about the z axis (on the x-y plane) [deg] \n' ...
    'distanceFromOrigin_mm - distance between origin (0,0,0) to the plane [mm]\n' ...
...    'xPlaneUFunc_pix - This describes the projection of the plane x=c on to the histology section the fuction recives v [pix] and c and returns u_pix\n' ...
...    'yPlaneUFunc_pix - This describes the projection of the plane y=c on to the histology section the fuction recives v [pix] and c and returns u_pix\n' ...
...    'zPlaneVFunc_pix - This describes the projection of the plane z=c on to the histology section the fuction recives u [pix] and c and returns v_pix\n' ...
    'xIntercept_mm - (x,y) position of where histology plane hits x=0 plane (average position) [mm]\n' ...
    'yIntercept_mm - (x,y) position of where histology plane hits y=0 plane (average position) [mm]\n' ...
    'Parameters when viewing from the top, approximation if tilt was 0[deg], y=mx+n:\n' ...
    ' * m,n - equation that defines the plane\n' ...
    ' * xFunctionOfU - 2vector (to be used by polyvar) converts u coordinates to x\n'...
    ' * vTypical - tyical value for v (in pixels) to multiply by the vector v\n' ... 
    'sizeChange_precent - if negative value, isotropic shrinkage of the histology compared to OCT. If positive, expansion [%]. sizeChange_precent = 50 means 50% epansion.\n' ...
    ]);

%% Plane parameters
singlePlaneFit.u = u;
singlePlaneFit.v = v;
singlePlaneFit.h = h;

n = -cross(u,v); %Compute norm vector to the plane, right hand role (normal is y direction)
n = n/norm(n);
singlePlaneFit.normal = n;
singlePlaneFit.d = dot(n,h);

%% Top plane approximation
pt1 = 0*u+v_*v+h;
pt2 = 1*u+v_*v+h;
dp = pt2-pt1;
ml = dp(2)/dp(1);
nl = pt1(2)-pt1(1)*ml;

singlePlaneFit.m = ml;
singlePlaneFit.n = nl;
singlePlaneFit.vTypical = v_;
singlePlaneFit.xFunctionOfU = polyfit([0,1],[pt1(1) pt2(1)],1);
singlePlaneFit.xFunctionOfU = singlePlaneFit.xFunctionOfU(:);

%% Size Change
sizeChange = 100*(( pixelSize_um / ((norm(u)+norm(v))/2*1e3)  )-1); 
singlePlaneFit.sizeChange_precent = sizeChange;

%% Compute general gemoetry
tilt = asin(n(3))*180/pi; %[deg]
rotation = 90-atan2(-n(2),n(1))*180/pi; %[orientation]
if (rotation > 180)
    rotation = rotation-360;
end
dFromOrigin = abs(dot(h,n));

singlePlaneFit.tilt_deg = tilt;
singlePlaneFit.rotation_deg = rotation;
singlePlaneFit.distanceFromOrigin_mm = dFromOrigin;

%% Cross sections projections
%Compute x & y intercept and how should they appear in the image

xPlaneUFunc_pix = @(vint,c)(-v(1)/u(1)*vint-h(1)/u(1)+c/u(1)); %x=c
yPlaneUFunc_pix = @(vint,c)(-v(2)/u(2)*vint-h(2)/u(2)+c/u(2)); %y=c
zPlaneVFunc_pix = @(uint,c)(-u(3)/v(3)*uint-h(3)/v(3)+c/v(3)); %z=c

%0 intercepts
yOfYIntercept = xPlaneUFunc_pix(v_,0)*u(2)+v_*v(2)+h(2);
xOfXIntercept = yPlaneUFunc_pix(v_,0)*u(1)+v_*v(1)+h(1);
singlePlaneFit.xIntercept_mm = [xOfXIntercept;0];
singlePlaneFit.yIntercept_mm = [0;yOfYIntercept];

%% Other parameters
singlePlaneFit.fitScore = []; %Not used by all structures
singlePlaneFit.version = 1.1;