function section = resliceOCTVolume(u,v,h,s,thickness,OCTVolumeFile,OCTVolumePosition)
%This function will Load OCT Vloume, and output the correspondent slice
%INPUTS:
%   octVolume - OCT data, dimensions should be (x,y,z)
%	topLeftBottomRight - defines the actual position [m] of the top left
%       (1,1) voxel, and bottom right (end,end)
%   Plane Parameters:
%       u,v,h - plane parameters (x,y,z)
%       s - how many pixels in z,x directions (v,u). Will image from (0,0) to s
%   Volume Parameters:
%       OCTVolumeFile - OCT Data File (TIF)
%       OCTVolumePosition - 6 element vector defining the top left (point index
%           1,1,1) and bottom right (point index end,end,end) of the OCT
%           volume in 3D real space - [m] x,y,z
%OUTPUT:
%   section - just the section part, interpolated

if length(h)==2 || isnan(h(3))
    %No value for h(3). Invent one
    h(3) = 0;
end

%% Find what is the 'real' position of the points on the histology section
upix = (1:s(2))-1; %[0:511]
vpix = (1:s(1))-1; %[0:511]
wpix =  -floor(thickness/2)+1:ceil(thickness/2);
[uupix,vvpix,wwpix] = meshgrid(upix,vpix,wpix); %0:511x0:511 meshgrid

uvcross = cross(u,v)/mean([norm(u),norm(v)]);
X = u(1)*uupix + v(1)*vvpix + h(1) + uvcross(1) * (wwpix-1); %512x512
Y = u(2)*uupix + v(2)*vvpix + h(2) + uvcross(2) * (wwpix-1);
Z = u(3)*uupix + v(3)*vvpix + h(3) + uvcross(3) * (wwpix-1);

%% Convert phisical X,Y,Z to OCT pixels coordinates
info = imfinfo(OCTVolumeFile);
xUnits = linspace(OCTVolumePosition(1),OCTVolumePosition(4),info(1).Width); %[-.001 to 0.001]
zUnits = linspace(OCTVolumePosition(3),OCTVolumePosition(6),info(1).Height); %[0 to 0.015]
yUnits = linspace(OCTVolumePosition(2),OCTVolumePosition(5),length(info)); %[-.001 to 0.001]

%For each point in the plane, determine what index should it have
Xi = interp1(xUnits,1:length(xUnits),X,'linear',NaN);  %512x512
Yi = interp1(yUnits,1:length(yUnits),Y,'linear',NaN);
Zi = interp1(zUnits,1:length(zUnits),Z,'linear',NaN);

%% Load OCT volume in batches
Yunique = unique(round(Yi(:)));
Yunique(isnan(Yunique)) = [];
YSlicesToLoadAtOnce = 19-1; %Use high number for good adapotization value

pad = 4; %paddig of 2 is required for linear interpolation, more if you would like to add gaussian smoothing of 3D
YiToLoadStart = (min(Yunique)-pad):(YSlicesToLoadAtOnce-pad):(max(Yunique)+pad);
YiToLoadEnd = YiToLoadStart+YSlicesToLoadAtOnce;
YiToLoadEnd(YiToLoadEnd>length(info)) = length(info);
YiToLoadStart(YiToLoadStart<1) = 1;

%Interpolate in parts
section = zeros(size(Xi));
for i=1:length(YiToLoadStart)
    i
    
    % Skip if YiToLoadStart greater than image size
    if YiToLoadStart(i) > length(info)
        continue
    end
    
    %% Load subset of OCT
    scanAbs = yOCTFromTif(OCTVolumeFile,YiToLoadStart(i):YiToLoadEnd(i));
    
    %Smooth image around
    scanAbs = log(imgaussfilt3(exp(scanAbs),1));

    %Re-arange dimensions such that scanAbs is (y,x,z) like the meshgrid to follow
    scanAbs = permute(scanAbs,[3 2 1]);
    
    %% Interpolate
    [xxi,yyi,zzi] = meshgrid(...
        1:length(xUnits),...
        YiToLoadStart(i):YiToLoadEnd(i),...
        1:length(zUnits));

    sectionTmp = (interp3(...
        xxi,yyi,zzi,(scanAbs), ...
        Xi,Yi,Zi,'linear', ...
        NaN ... %Extrapulation value
        )); 

    msk = (~isnan(sectionTmp)) & (Yi>=YiToLoadStart(i)+pad/2) & (Yi<YiToLoadEnd(i)-pad/2);
    section(msk) = sectionTmp(msk);
    
    %% Plot Volume as it been rebuild
    figure(3);
    imagesc(section(:,:,1));
    colormap gray;
    title(sprintf('Building OCT Slice... (%.1f%% Complete)',100*i/length(YiToLoadStart)));
    pause(0.01);
end

return;
%% Backup & debug
imagesc(interp3(...
        xxi,yyi,zzi,yyi, ...
        Xi,Yi,Zi,'linear', ...
        0 ... %Extrapulation value
        ));