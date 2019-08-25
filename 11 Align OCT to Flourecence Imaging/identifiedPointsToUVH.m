function [u,v,h] = identifiedPointsToUVH (varargin)
%Use the identified points hashtag lines to estimate what is the u,v,h
%vectors. Solving a least square structure.
%USAGE:
%   [u,v,h] = identifiedPointsToUVH(vPointU,vPointV,vPointLocation,hPointU,hPointV,hPointLocation)
%       or
%   [u,v,h] = identifiedPointsToUVH(photobleachedLines)
%INPUTS:
%   vPointU,vPointV - points that recognize the vertical line (up / down, x=c)
%   vPointLocation - line position (that c)
%   The same hPointU,hPointV,hPointLocation
%   photobleachedLines - photobleached lines structure
%OUTPUTs
%   u - the real space coordinates of image's u direction (units of meters): (x,y,z)
%   v - the real space coordinates of images's v direction (units of meters): (x,y,z)
%   h - location of image's origin (point 0*u + 0*v, sometimes called top
%       left corner of the image): (x,y,z)
%Notice:
%   To compute u(z),v(z) we assume
%       1) Histology image can isometirally shrink |u|=|v|
%       2) No shearing: u*v=0

%% Input checks

if length(varargin)==1
    pls = varargin{1};
    
    vPointU = [];
    vPointV = [];
    hPointU = [];
    hPointV = [];
    vPointLocation = [];
    hPointLocation = [];
    for i=1:length(pls)
        switch(lower(pls(i).group))
            case 'v'
                vPointU = [vPointU pls(i).u_pix(:)'];
                vPointV = [vPointV pls(i).v_pix(:)'];
                vPointLocation = [vPointLocation repmat(pls(i).linePosition_mm,1,length(pls(i).u_pix))];
            case 'h'
                hPointU = [hPointU pls(i).u_pix(:)'];
                hPointV = [hPointV pls(i).v_pix(:)'];
                hPointLocation = [hPointLocation repmat(pls(i).linePosition_mm,1,length(pls(i).u_pix))];
        end
    end
    
else
    %Already given in the open structure
end

%Input checks
if length(hPointU)<3
    error('Need more h points!');
elseif length(vPointU)<3
    error('Need more v points!');
end

%% Build Matrix
zv = zeros(length(vPointU),1);
ov = zv+1;

zh = zeros(length(hPointU),1);
oh = zh+1;

A = [ ...
    vPointU(:)     zv      vPointV(:)      zv     ov zv; ...
      zh        hPointU(:)    zh       hPointV(:) zh oh; ...
    ];

lnDist = [vPointLocation(:);hPointLocation(:)];

%% Solve Least Square Problem for x-y plane
%weight least suqares - disabled
%W = ptsRes .^1;
%tmp = (A'*diag(W)*A)^-1*A'*diag(W)*lnDist;

tmp = A\lnDist;
u = tmp(1:2); u = u(:);
v = tmp(3:4); v = v(:);
h = tmp(5:6); h = h(:);

if (norm(u) < norm(v))
    error('It seems that v is not pointed towards z axis. Probably something is wrong in the estimation');
end

%% Solve z by solving non linear cuppled equation
A = u(1)*v(1)+u(2)*v(2);
B = u(1)^2-v(1)^2+u(2)^2-v(2)^2;

v(3) = 1/sqrt(2)*sqrt(B+sqrt(B^2-4*A^2));
u(3) = -A/v(3);

%% Solve h(3) by comparing interface height
h(3) = NaN;
