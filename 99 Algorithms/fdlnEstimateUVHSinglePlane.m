function [u,v,h] = fdlnEstimateUVHSinglePlane (fdln,a,b)
%Uses Fiducial Line structure of identified markers to identify u,v,h assuming a single plane approiximation
%INPUTS:
%   fdln - array of identified Fiducial Line structures (see
%       fdlnIsLineIdentified for explanaition, of what is 'identified')
%   a - How well the orthogonality assumption holds: u*v = a*|u||v|
%       if assumption completely holds, a = 0 (default)
%   b - How well the isotropic shrinkage holds: |u|^2 - |v|^2 = b*|u||v|
%       if assumption completely holds, b = 0 (default)
%OUTPUTS:
%   u - the real space coordinates of image's u/x direction (units of mm): (x,y,z)
%   v - the real space coordinates of images's v/y direction (units of mm): (x,y,z)
%   h - location of image's origin (point 0*u + 0*v, sometimes called top
%       left corner of the image): (x,y,z). If no tissue interface is found
%       h(3) = NaN as it cannot be estimated without tissue interface

%% Input checks
if ~exist('a','var')
    a = 0;
end
if ~exist('b','var')
    b = 0;
end

gr = [fdln.group];
if (sum(gr == 'v') < 2)
    error('Not enugh fiducial lines are identified as ''v'' (vertical), need at least 2');
elseif (sum(gr == 'h') < 2)
    error('Not enugh fiducial lines are identified as ''h'' (horizontal), need at least 2');
end

%% Convert lines to points
pt_v_u = zeros(size([fdln(gr == 'v').u_pix])); pt_v_u = pt_v_u(:);
pt_v_v = pt_v_u;
pos_v = pt_v_u;
fdlnsI = find(gr == 'v'); n=1;
for i=1:length(fdlnsI)
   f = fdln(fdlnsI(i)); 
   for j=1:length(f.u_pix)
       pt_v_u(n) = f.u_pix(j);
       pt_v_v(n) = f.v_pix(j);
       pos_v(n) = f.linePosition_mm;
       n = n+1;
   end
end

pt_h_u = zeros(size([fdln(gr == 'h').u_pix])); pt_h_u = pt_h_u(:);
pt_h_v = pt_h_u;
pos_h = pt_h_u;
fdlnsI = find(gr == 'h'); n=1;
for i=1:length(fdlnsI)
   f = fdln(fdlnsI(i)); 
   for j=1:length(f.u_pix)
       pt_h_u(n) = f.u_pix(j);
       pt_h_v(n) = f.v_pix(j);
       pos_h(n) = f.linePosition_mm;
       n = n+1;
   end
end

%% Solve Least Square Problem for x-y plane
zv = zeros(size(pt_v_u));
ov = zv+1;

zh = zeros(size(pt_h_u));
oh = zh+1;

A = [ ...
    pt_v_u,   zv  , pt_v_v,   zv  , ov zv; ...
      zh  , pt_h_u,   zh  , pt_h_v, zh oh; ...
    ];

lnDist = [pos_v;pos_h];

tmp = A\lnDist;
u = tmp(1:2); u = u(:);
v = tmp(3:4); v = v(:);
h = tmp(5:6); h = h(:);

if (norm(u) < norm(v))
    error('It seems that v is not pointed towards z axis. Probably something is wrong in the estimation');
end

%% Solve z by solving non linear cuppled equation
A_ = @(u,v,a) u(1)*v(1)+u(2)*v(2)         -a*norm(u)*norm(v);
B_ = @(u,v,b) u(1)^2-v(1)^2+u(2)^2-v(2)^2 -b*norm(u)*norm(v);

vz = @(A,B) (1/sqrt(2)*sqrt(B+sqrt(B^2-4*A^2)));

%Iteration #1, assuming a,b=0 for order of magnitude estimation
A = A_(u,v,0); B = B_(u,v,0);
v(3) = vz(A,B);
u(3) = -A/v(3);

%Iteration #2 include shearing effects
if (a~=0 || b~=0)
    A = A_(u,v,a); B = B_(u,v,b);
    v(3) = vz(A,B);
    u(3) = -A/v(3);
end

%% Solve hz using tissue interface if exists
tI = [fdln.group] == 't';
if (sum(tI) == 0)
    %No tissue interface, cann't estimate hz
    h(3) = NaN;
else
    t_u_pix = [fdln(tI).u_pix]; t_u_pix = t_u_pix(:);
    t_v_pix = [fdln(tI).v_pix]; t_v_pix = t_v_pix(:);
    
    uInterface = mean(t_u_pix);
    vInterface = mean(t_v_pix);
    
    zInterface = mean([fdln(tI).linePosition_mm]);
    
    h(3)= - uInterface*u(3) - vInterface*v(3) + zInterface; 
end
