function section = resliceOCTVolume(u,v,h,s,OCTVolumeFolder,OCTVolumePosition,OCTSystem,dispersionParameterA)
%This function will Load OCT Vloume, and output the correspondent slice
%INPUTS:
%   octVolume - OCT data, dimensions should be (x,y,z)
%	topLeftBottomRight - defines the actual position [m] of the top left
%       (1,1) voxel, and bottom right (end,end)
%   Plane Parameters:
%       u,v,h - plane parameters (x,y,z)
%       s - how many pixels in z,x directions (v,u). Will image from (0,0) to s
%   Volume Parameters:
%       OCTVolumeFolder - OCT Data folder
%       OCTVolumePosition - 6 element vector defining the top left (point index
%           1,1,1) and bottom right (point index end,end,end) of the OCT
%           volume in 3D real space - [m] x,y,z
%       OCTSystem - OCT System Name. Default: Wasatch
%       dispersionParameterA - for OCT loading
%OUTPUT:
%   section - just the section part, interpolated

if length(h)==2 || isnan(h(3))
    %No value for h(3). Invent one
    h(3) = 0;
end

if ~exist('OCTSystem','var')
    OCTSystem = 'Wasatch';
end

%% Find what is the 'real' position of the points on the histology section
upix = (1:s(2))-1;
vpix = (1:s(1))-1;
[uupix,vvpix] = meshgrid(upix,vpix);

X = u(1)*uupix + v(1)*vvpix + h(1);
Y = u(2)*uupix + v(2)*vvpix + h(2);
Z = u(3)*uupix + v(3)*vvpix + h(3);

%% Convert phisical X,Y,Z to OCT pixels coordinates
dim = yOCTLoadInterfFromFile(OCTVolumeFolder,'OCTSystem',OCTSystem,'PeakOnly',true);
dim.x.values = linspace(OCTVolumePosition(1),OCTVolumePosition(4),length(dim.x.values));
dim.x.units = 'm';
dim.y.values = linspace(OCTVolumePosition(2),OCTVolumePosition(5),length(dim.y.values));
dim.y.units = 'm';
dim.z.values = linspace(OCTVolumePosition(3),OCTVolumePosition(6),length(dim.lambda.values)/2);
dim.z.units = 'm';
dim.z.index = 1:length(dim.z.values);

Xi = interp1(dim.x.values,dim.x.index,X,'linear',NaN);
Yi = interp1(dim.y.values,dim.y.index,Y,'linear',NaN);
Zi = interp1(dim.z.values,dim.z.index,Z,'linear',NaN);

%% Load OCT volume in batches
Yunique = unique(round(Yi(:)));
Yunique(isnan(Yunique)) = [];
YSlicesToLoadAtOnce = 20-1; %Use high number for good adapotization value

pad = 2;
YiToLoadStart = (min(Yunique)-pad):(YSlicesToLoadAtOnce-pad):(max(Yunique)+pad);
YiToLoadEnd = YiToLoadStart+YSlicesToLoadAtOnce;
YiToLoadEnd(YiToLoadEnd>max(Yunique)+pad) = max(Yunique)+pad;

%Interpolate in parts
section = zeros(size(Xi));
for i=1:length(YiToLoadStart)
    %% Load subset of OCT
    %Load Intef From file
    [interf,dimensions] = yOCTLoadInterfFromFile(OCTVolumeFolder,'OCTSystem',OCTSystem,...
        'YFramesToProcess',YiToLoadStart(i):YiToLoadEnd(i));
    
    [interf,dimensions] = yOCTEquispaceInterf(interf,dimensions); %For Faster excecution

    %Generate BScans
    scanCpx = yOCTInterfToScanCpx(interf,dimensions ...
        ,'dispersionParameterA', dispersionParameterA ...Use this dispersion Parameter for air-water interface
        );

    %Average B Scan Averages
    scanAbs = mean(abs(scanCpx),4);

    %Re-arange dimensions such that scanAbs is (x,y,z)
    scanAbs = shiftdim(scanAbs,1);
    
    %% Interpolate
    [yyi,xxi,zzi] = meshgrid(dimensions.y.index,dimensions.x.index,dim.z.index);

    sectionTmp = interp3(...
        yyi,xxi,zzi,scanAbs, ...
        Yi,Xi,Zi,'linear', ...
        0 ... %Extrapulation value
        ); 

    msk = (sectionTmp>0) & (Yi>=YiToLoadStart(i)+pad/2) & (Yi<YiToLoadEnd(i)-pad/2);
    section(msk) = sectionTmp(msk);
    
    %% Plot Volume as it been rebuild
    figure(3);
    imagesc(log(section));
    colormap gray;
    title(sprintf('Building OCT Slice... (%.1f%% Complete)',100*i/length(YiToLoadStart)));
    pause(0.01);
end

return;
%% Backup & debug
imagesc(interp3(...
        yyi,xxi,zzi,yyi, ...
        Yi,Xi,Zi,'linear', ...
        0 ... %Extrapulation value
        ));
