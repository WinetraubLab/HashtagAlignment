%User interface. Finds the intersection of several gaussian beams with a
%plane described by u, v, h.  Assumes that each photobleach plane is a
%2d gaussian profile beam that is repeated in the 3rd dimension
% 
%USAGE:
%   img = gaussian_pb(E0, w0, lambda, t, z0, u, v, h, lnDist, lnDir)
%INPUTS:
%   E0 - Electric field amplitude
%   w0 - beam width [meters]
%   lambda - center wavelength [meters]
%   t - duration of photobleach [arbitrary units]
%   z0 - z focal position of photobleaching beam
%   u - u vector of slicing plane
%   v - v vector of slicing plane
%   h - h vector of slicing plane
%   lnDist - array containing intercept points of hashtag lines
%   lnDir - array indicating orientation of each hashtag line
%OUTPUTs
%   img - an image showing the slice described by u, v, h
%   

function img = gaussian_pb(E0, w0, lambda, t, z0, u, v, h, lnDist, lnDir)
[umesh,vmesh]=meshgrid([1:512],[1:512]);
rmat = umesh*u(1) + vmesh*v(1) + h(1);
zmat = umesh*u(3) + vmesh*v(3) + h(3) - z0;

zr = pi*w0^2/lambda;
wz = w0*sqrt(1+(zmat/zr).^2);

% y-lines
x=lnDist(lnDir==1);
img = ones(512,512);
for xi = 1:length(x)
    img = img.* exp(-(E0.*(w0./wz).*exp(-(rmat-x(xi)).^2./wz.^2)).^2 * t);
end

% x-lines
rmat = umesh*u(2) + vmesh*v(2) + h(2);

y=lnDist(lnDir==0);
for yi = 1:length(y)
    img = img.* exp(-(E0.*(w0./wz).*exp(-(rmat-y(yi)).^2./wz.^2)).^2 * t);
end
