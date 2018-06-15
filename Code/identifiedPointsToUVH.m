function [u,v,h] = identifiedPointsToUVH (pts,lnDist, lnDir)
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
%       pts =    [ 15 10;  15 50;  25 10; -15 10; -15 50; -25 10];
%       lnDist = [-50e-6; -50e-6; +50e-6; -50e-6; -50e-6; +50e-6];
%       lnDir =  [ 0     ; 0    ;  0    ;  1    ;  1    ;  1    ];

%% Build Matrix
npts = size(pts,1);
z = zeros(npts,1);
o = z+1;

A = [pts(:,1) z pts(:,2) z o z].*(lnDir == 1) + [z pts(:,1) z pts(:,2) z o].*(lnDir == 0);

%% Solve Least Square Problem for x-y plane
tmp = A\lnDist;
u = tmp(1:2); u = u(:);
v = tmp(3:4); v = v(:);
h = tmp(5:6); h = h(:);

%% Solve z by solving non linear cuppled equation

zvLim = [0 2]*max([norm(u(1:2)) norm(v(1:2))]); %Choose zv that points on image down
for k=1:20
    %All options for zv
    zv = linspace(zvLim(1),zvLim(2),1e2);

    %Equal Norm Condtion
    zu_1 = (sqrt(zv.^2 + norm(v).^2 - norm(u).^2)); 
    zu_1(imag(zu_1)>0) = Inf; %If imaginary, reject solution
    zu_2 = -zu_1;

    %Dot Product Condition
    ddot_1 = ((zu_1.*zv-dot(u,v)));
    ddot_2 = ((zu_2.*zv-dot(u,v)));

    if false
        %Debug plots
        plot(zv,(ddot_2),zv,(ddot_1),zv,zv*0);
        m = min(abs([ddot_2 ddot_1]));
        ylim(m*[-50 50]);
        pause(1)
    end

    %Find Best Fit
    zzv = [zv zv];
    zzu = [zu_1 zu_2];
    ddot = [ddot_1 ddot_2];
    i = find (abs(ddot)==min(abs(ddot)),1,'first');
    
    dzv = zv(2)-zv(1);
    zvLim = zzv(i) + 5*[-dzv dzv];
    
    if (abs(dot([u;zzu(i)],[v;zzv(i)])/(norm([u;zzu(i)]).*norm([v;zzv(i)]))*180/pi)<5)
        break;
    end
end
v(3)=double(zzv(i));
u(3)=double(zzu(i));
%dot(u,v)./(norm(u)*norm(v))*180/pi

