function [ptStart_Scan, ptEnd_Scan, ptStart_Extended, ptEnd_Extended] = ScanAndPattern_GeneratePatternToPhotobleach(config)
%This auxilary function will generate line set to photobleach as part of
%the scan and the extended lines

epsilon = 10e-3; % mm, small buffer number

ptStart = [];
ptEnd = [];

ini = yOCTReadProbeIniToStruct(config.octProbePath);

%% H & V Lines
lshort = config.photobleach.lineLength;

if (~config.photobleach.isPhotobleachOverview)
    lx = lshort;
    ly = lshort;
else
    lx = config.overview.rangeAllX;
    ly = config.overview.rangeAllY;
end

%v Lines
%Photobleach overview only the 3 lines closest to origin
vLinePositions = config.photobleach.vLinePositions;
[~,vI] = sort(abs(vLinePositions)); 
vI = vI(1:min(length(vLinePositions),3));
for i=1:length(vLinePositions)
    if(ismember(i,vI))
        myl = ly/2;
    else
        myl = lshort/2;
    end
    
    ptStart(:,end+1) = [vLinePositions(i);-myl]; %Start
    ptEnd(:,end+1)   = [vLinePositions(i);+myl]; %Ebd
end

%h Lines
%Photobleach overview only the 3 lines closest to origin
hLinePositions = config.photobleach.hLinePositions;
[~,hI] = sort(abs(hLinePositions)); 
hI = hI(1:min(length(hLinePositions),3));
for i=1:length(hLinePositions)
    if(ismember(i,hI))
        myl = lx/2;
    else
        myl = lshort/2;
    end

    ptStart(:,end+1) = [-myl; hLinePositions(i)]; %Start
    ptEnd(:,end+1)   = [+myl; hLinePositions(i)]; %Ebd
end

%% Tick marks 
if (config.photobleach.isDrawTickmarks)

    %Make sure tick marks don't collide with regular lines
    clrnce = 0.1;
    isCleared = @(x,y)( ...
        ( ...
            x < (min (config.photobleach.vLinePositions)-clrnce) | ...
            x > (max (config.photobleach.vLinePositions)+clrnce)   ...
        ) & ( ... 
            y < (min (config.photobleach.hLinePositions)-clrnce) | ...
            y > (max (config.photobleach.hLinePositions)+clrnce)   ...
        ) );
    for i=1:length(config.photobleach.tickmarksX0)
        c = [config.photobleach.tickmarksX0(i)/2; config.photobleach.tickmarksY0(i)/2];
        v = [config.photobleach.tickmarksX0(i); -config.photobleach.tickmarksY0(i)]; v = v/norm(v);

        [pts,pte] = yOCTApplyEnableZone(...
            c-v*max([config.photobleach.lineLength, 2]), ... mm
            c+v*max([config.photobleach.lineLength, 2]), ... mm
            isCleared, epsilon);

        ptStart = [ptStart pts];
        ptEnd = [ptEnd pte];
    end
end

if config.photobleach.isDrawTheDot
    ptStart = [ptStart ([ config.theDotX+0.1*[-1 0] ; config.theDotY+0.1*[0 -1]])];
    ptEnd   = [ptEnd   ([ config.theDotX+0.1*[+1 0] ; config.theDotY+0.1*[0 +1]])];
end

%% Enabled & disabled switches
if ~config.photobleach.isPhotobleachOverview
    %Trim everything to one FOV if it doesn't fit
    [ptStart,ptEnd] = yOCTApplyEnableZone(ptStart, ptEnd, ...
            @(x,y)(abs(x)<ini.RangeMaxX/2 & abs(y)<ini.RangeMaxY/2) , epsilon);
end

if (~config.photobleach.isPhotobleachEnabled)
    ptStart = [];
    ptEnd = [];
end

%% Seperate Photobleaching
[ptStart_Scan,ptEnd_Scan] = yOCTApplyEnableZone(ptStart, ptEnd, ...
    @(x,y)(abs(x)<ini.RangeMaxX/2-epsilon & abs(y)<ini.RangeMaxY/2-epsilon) , epsilon);

%Overview / extended
%Dont photobleach in that area during overview, it is to be photobleached
%only once
keepPhotobleachOut = @(x,y) (...
    (abs(x)<ini.RangeMaxX/2 + config.photobleach.photobleachOverviewBufferZone) & ...
    (abs(y)<ini.RangeMaxY/2 + config.photobleach.photobleachOverviewBufferZone)   ...
    ); 

[ptStart_Extended,ptEnd_Extended] = yOCTApplyEnableZone(ptStart, ptEnd, ...
            @(x,y)(~keepPhotobleachOut(x,y)) , epsilon);

%% Make a figurePlot
ptStartplot = [ptStart_Scan ptStart_Extended];
ptEndplot =   [ptEnd_Scan   ptEnd_Extended];
figure(2); subplot(1,1,1);
for i=1:size(ptStartplot,2)
    plot([ptStartplot(1,i) ptEndplot(1,i)], [ptStartplot(2,i) ptEndplot(2,i)]);
    if (i==1)
        hold on;
    end
end
rectangle('Position',[-config.volume.xRange/2 -config.volume.yRange/2 config.volume.xRange config.volume.yRange]);
hold off;
axis equal;
axis ij;
grid on;
xlabel('x[mm]');
ylabel('y[mm]');

%% Check that length of lines is never more or less than what we can
if any( sqrt(sum((ptStart_Scan - ptEnd_Scan).^2)) > ini.RangeMaxX)
    error('One (or more) of the photobleach lines is longer than the allowed size, this might cause photobleaching errors!');
end

% Don't photobleach shorter distance than 10% of the range
ini =  yOCTReadProbeIniToStruct(config.octProbePath);
minDist = ini.RangeMaxX*0.1;
if any( sqrt(sum((ptStart_Scan - ptEnd_Scan).^2)) < minDist)
    error('One (or more) of the photobleach lines is shorter than the allowed size, this might cause photobleaching errors!');
end
