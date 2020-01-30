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



