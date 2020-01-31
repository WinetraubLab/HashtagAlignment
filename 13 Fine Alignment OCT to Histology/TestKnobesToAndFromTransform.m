% This function tests knobes to and from transform

%% Basic tests

% 2 microns per pixel, no rotation, x translation of 10 microns
T = knobesToTransform(2,0,10,0,1);
assert(all([0 0 1]*T==[10 0 1]),'Baseline translation');
assert(all([1 0 1]*T==[12 0 1]),'1 pixel translation x');
assert(all([0 1 1]*T==[10 2 1]),'1 pixel translation z');

% 2 microns per pixel, 90 degrees rotation, x translation of 10 microns
T = knobesToTransform(2,90,10,0,1);
assert(all([0 0 1]*T==[10 0 1]),'Baseline translation');
assert(all(abs([1 0 1]*T-[10 2 1])<1e-3),'1 pixel translation x');
assert(all(abs([0 1 1]*T-[8 0 1])<1e-3),'1 pixel translation z');

%% Consistancy
knobes = (2*rand(1,5)-1).*[1 180 100 100 1];
knobes([1 5]) = abs(knobes([1 5]));
knobes = [0.5 90 10 10 0.7]; %Image scale um/pix, rotation,xTranslation,zTranslation,octScanle
T = knobesToTransform(knobes(1),knobes(2),knobes(3),knobes(4),knobes(5));
[knobes_(1),knobes_(2),knobes_(3),knobes_(4)] = transform2Knobes (T,knobes(5));
knobes_(5) = knobes(5);
assert(all(abs(knobes-knobes_)<1e-3),'Back and forth consistancy');

%% u,v,h to transform

% Simplest transform
u = [1 0 0];
v = [0 0 1];
h = [0 0 0];
T = octSlideToTransform(u,v,h,diag([1 1 1]),0,0,1,1);
assert(all(all(abs(T-diag([1 1 1]))<1e-3)),'Simplist transform');

% Translation
u = [1 0 0];
v = [0 0 1];
h = [-0.5 0 0];
T = octSlideToTransform(u,v,h,diag([1 1 1]),-1,0,1,1);
Tref = [1 0 0; 0 1 0; 500 0 1];
assert(all(all(abs(T-Tref)<1e-3)),'Small translation transform');

% Rotation order directions
u = [1 0 0.05]; u = u/norm(u)*1e-3; %1um pixel
v = [-0.05 0 1]; v = v/norm(v)*1e-3; %1um pixel
h = [0.200 0 0.300];
T = octSlideToTransform(u,v,h,diag([1 1 1]),0,0,1,1);
assert(all(abs([0 0 1]*T - [h(1)*1e3 h(3)*1e3 1])<1e-6),'h where it should be')
assert(all(abs([1 0 1]*T-[0 0 1]*T - [u(1)*1e3 u(3)*1e3 0])<1e-6),'u direction where it should be')
assert(all(abs([0 1 1]*T-[0 0 1]*T - [v(1)*1e3 v(3)*1e3 0])<1e-6),'v direction where it should be')

%% u,v,h to transform - consistency

% Real u,v,
pixelSize = 1e-3;
u = [0 1 0]*pixelSize; u = u(:);
v = [0 0 1]*pixelSize; v = v(:);

% Generate a transformation for the resliced volume
wHat =  -cross(u/norm(u),v/norm(v));
new2OriginalAffineTransform = [u/norm(u) wHat v/norm(v)];

% Rotate the transformation 'along plane', i.e. along y axis
t = rand(1)*2*pi;
c = cos(t); s=sin(t);
new2OriginalAffineTransform = new2OriginalAffineTransform*[c 0 s; 0 1 0; -s 0 c;];

h = [0.200 0 0.300]'; %mm
%h = [0 0 0]';

tmp = new2OriginalAffineTransform^-1*h;
planeDistanceFromOrigin_mm = tmp(2);
octScale_umperpix = rand(1);
topLeftCornerXmm = rand(1);
topLeftCornerZmm = rand(1);
scale_umperpix = norm(u)*1e3;

T = octSlideToTransform(u,v,h,new2OriginalAffineTransform,topLeftCornerXmm,topLeftCornerZmm,scale_umperpix,octScale_umperpix);

[u_,v_,h_] = transformToOctSlide(...
    T,new2OriginalAffineTransform,topLeftCornerXmm,topLeftCornerZmm,octScale_umperpix, planeDistanceFromOrigin_mm);

assert(all(abs(u - u_)<1e-9),'u problem');
assert(all(abs(v - v_)<1e-9),'v problem');
assert(all(abs(h - h_)<1e-9),'h problem');
