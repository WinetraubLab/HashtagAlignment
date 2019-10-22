function [ptStart_Scan, ptEnd_Scan, ptStart_Extended, ptEnd_Extended] = ScanAndPattern_GeneratePatternToPhotobleach(config)
%This auxilary function will generate line set to photobleach as part of
%the scan and the extended lines

ptStart = [];
ptEnd = [];

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
[~,vI] = sort(abs(vLinePositions)); vI = vI(1:3);
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
[~,hI] = sort(abs(hLinePositions)); hI = hI(1:3);
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
            c-v*config.photobleach.lineLength, ...
            c+v*config.photobleach.lineLength, ...
            isCleared, 10e-3);

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
            @(x,y)(abs(x)<config.octProbeFOV(1)/2 & abs(y)<config.octProbeFOV(2)/2) , 10e-3);
end

if (~config.photobleach.isPhotobleachEnabled)
    ptStart = [];
    ptEnd = [];
end

%% Seperate Photobleaching

[ptStart_Scan,ptEnd_Scan] = yOCTApplyEnableZone(ptStart, ptEnd, ...
    @(x,y)(abs(x)<config.octProbeFOV(1)/2 & abs(y)<config.octProbeFOV(2)/2) , 10e-3);

%Overview / extended
%Dont photobleach in that area during overview, it is to be photobleached
%only once
keepPhotobleachOut = @(x,y) (...
    (abs(x)<config.octProbeFOV(1)/2 + config.photobleach.photobleachOverviewBufferZone) & ...
    (abs(y)<config.octProbeFOV(2)/2 + config.photobleach.photobleachOverviewBufferZone)   ...
    ); 

[ptStart_Extended,ptEnd_Extended] = yOCTApplyEnableZone(ptStart, ptEnd, ...
            @(x,y)(~keepPhotobleachOut(x,y)) , 10e-3);

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
rectangle('Position',[-config.volume.rangeX/2 -config.volume.rangeY/2 config.volume.rangeY config.volume.rangeY]);
hold off;
axis equal;
axis ij;
grid on;
xlabel('x[mm]');
ylabel('y[mm]');