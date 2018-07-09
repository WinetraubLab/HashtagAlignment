%This script simulates images to be used with script1
close all;
clear;
%% Inputs
OCTVolumePosition = [-1e-3 -1e-3     0; ... %x,y,z position [m] of the first A scan in the first B scan (1,1)
                     +1e-3 +1e-3  0.968e-6*2040]';     %x,y,z position [m] of the las A scan in the last B scan (end,end). z is deeper!
lnDist = 1e-6*[-50  +50  -50    0  +50]; %Line distance from origin [m]
lnDir  =      [  0    0    1    1    1]; %Line direction 0 - left right, 1 - up down

NPixX = 500; %Number of pixels in each direction
NPixY = 400;
NPixZ = 100;
NPixIm = 500;


u = [1; -1; 0]; u = u/norm(u)*2e-6;
v = [0;  0; 1]; v = v/norm(v)*2e-6;
h = [-0.1e-3 0.6e-3 0];

%% X-Y Plane
x = linspace(OCTVolumePosition(1),OCTVolumePosition(4),NPixX);
y = linspace(OCTVolumePosition(2),OCTVolumePosition(5),NPixY);
[xx,yy] = meshgrid(x,y);

b = ones(size(xx)); %Canvas, (y,x)

%Draw lines
for i=1:length(lnDir)
    switch(lnDir(i))
        case 0
            f = exp(-(yy-lnDist(i)).^2/(2*5e-6^2)).*(xx>0);
        case 1
            f = exp(-(xx-lnDist(i)).^2/(2*5e-6^2)).*(yy>0);
    end
    
    b = b.*(1-f);
end
b(abs(xx-250e-6)<10e-6 & abs(yy-250e-6)<10e-6) = 0.5;

figure(1);
imagesc(x,y,b)
hold on;
plot(h(1)+u(1)*[0 NPixIm-1],h(2)+u(2)*[0 NPixIm-1]);
plot(h(1)+u(1)*[0],h(2)+u(2)*[0],'o');
hold off;
colormap gray;
axis xy;
xlabel('x[m]');
ylabel('y[m]');
pause(0.01);


%% Generate Volume
OCTVol(1,:,:) = b';%(z,x,y)
OCTVol = repmat(OCTVol,[NPixZ 1 1]);
yOCT2Tif(OCTVol,'scanAbs.tif');

%% Generate Image
xp = h(1)+u(1)*(0:(NPixIm-1));
yp = h(2)+u(2)*(0:(NPixIm-1));

im = interp2(xx,yy,b,xp,yp);
im = repmat(im,[NPixIm 1]);
imwrite(im,'1.tif');

figure(2);
imagesc(im);
colormap gray;
title('Scan');

