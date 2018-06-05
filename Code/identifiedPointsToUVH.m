function [u,v,h,d] = identifiedPointsToUVH (pts,lnDist, lnDir)
%Use the identified points hashtag lines to estimate what is the u,v,h
%vectors. Solving a least square structure.
%USAGE:
%   [u,v,h,d] = identifiedPointsToUVH (pts,lnDist, lnDir)
%INPUTS:
%   pts - containing position of points identified (in pixels)
%   lns - vector containing the distance of the line identified from the
%       origin (in meters)
%   lnDir - vector for each line is it of the form x=c, up/down (lnDir=1) or 
%       y=c, left/right (lnDir=0)
%OUTPUTs
%   u - the real space coordinates of image's u direction (units of meters): (x,y,z)
%   v - the real space coordinates of images's v direction (units of meters): (x,y,z)
%   h - location of image's origin (point 0*u + 0*v, sometimes called top
%       left corner of the image): (x,y,z)
%   d - when looking in a birds eye view. What is distance between each point
%       to the axis along the photobleach plane in [m]
%Notice:
%   To compute u(z),v(z) we assume
%       1) Histology image can isometirally shrink |u|=|v|
%       2) No shearing: u*v=0
%Example:
%   Let us assume 4 lines in the image:
%       n1,n2 parallel to y axis positioned in x=-50microns, x=+50 microns
%       n3,n4 parallel to x axis positioned in y=-50microns, y=+50 microns
%   On the histology image, we found 6 points at pixel positions
%       On n1: (10,10), (10,50)
%       On n2: (20,10)
%       On n3: (80,10), (80,50)
%       On n4: (90,10)
%   Then we shall run function as following:
%       pts =    [ 15 10;  15 50;  25 10  -15 10; -15 50; -25 10];
%       lnDist = [-50e-6; -50e-6; +50e-6; -50e-6; -50e-6; +50e-6];
%       lnDir =  [ 0     ; 0    ;  0    ;  1    ;  1    ;  1    ];

%% Build Matrix
npts = size(pts,1);
z = zeros(npts,1);
o = z+1;

A = [pts(:,1) z pts(:,2) z o z].*(lnDir == 1) + [z pts(:,1) z pts(:,2) z o].*(lnDir == 0);

%% Solve Least Square Problem for x-y plane
tmp = A\lnDist;
u(1:2) = tmp(1:2); u = u(:);
v(1:2) = tmp(3:4); v = v(:);
h(1:2) = tmp(5:6); h = h(:);

%% Solve z by solving non linear cuppled equation

%Define a cupled equations
f1 = @(a) (a(1)*a(2)+dot(u(1:2),v(1:2))); %Orthogonality Condition
f2 = @(a) (sqrt(a(1).^2-a(2).^2+sum(u(1:2).^2)-sum(v(1:2).^2))); %Norm Condition
F  = @(a) [f1(a); f2(a)];

%Solve
a = fsolve(F, ...
    max([norm(u(1:2)) norm(v(1:2))]).*[1 1]);
u(3) = a(1);
v(3) = a(2);
h(3) = NaN; %Cannot estimate hz

%% Bonus, compute d
d = repmat(pts(:,1),[1 2]).*repmat(u(1:2)',[size(pts,1) 1])+repmat(h(1:2)',[size(pts,1) 1]);
d = sqrt(sum(d.^2,2));

