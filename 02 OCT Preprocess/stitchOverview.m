%This script stitches overview file

%% Inputs
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-00D/OCTVolumes/';
dispersionParameterA = 6.539e07;

%Total width covered by histological sectioning 
histologyVolumeThickness = 15*5*(5+1); %[um]

isPlotEnface = true; %Set to true to plot enface, false to plot depth map

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
end

OCTVolumesFolder = awsModifyPathForCompetability([OCTVolumesFolder '\']);
SubjectFolder = awsModifyPathForCompetability([OCTVolumesFolder '..\']);

overviewOutputFolder = awsModifyPathForCompetability([SubjectFolder 'Log\01 OCT Scan and Pattern\Overview.png']); %Overview should be saved to the scan part as we use it to decide which side to cut and how deep
logFolder = [SubjectFolder 'Log\02 OCT Preprocess\'];
output3DOverviewVolume = awsModifyPathForCompetability([OCTVolumesFolder '/OverviewScanAbs/']);

%% Process overview scan
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);

if (length(json.overview.zDepts) > 1 && isfield(json,'focusPositionInImageZpix'))
    %Multiple depths, so try to stitch appropretly
    focusPositionInImageZpix = json.focusPositionInImageZpix;
    
    %Z projection parametres
    zStart = 1;
    zEnd = Inf;
else
    %One depth, just save all of it
    focusPositionInImageZpix = NaN;
    
    %Z projection parametres
    zStart = 100; %max(focusPositionInImageZpix - focusSigma*5,1);
    zEnd = 1000;  %min(focusPositionInImageZpix + focusSigma*7,1000);
end

setupParpolOCTPreprocess();
yOCTProcessTiledScan(...
    [OCTVolumesFolder 'Overview\'], ... Input
    output3DOverviewVolume,...
    'debugFolder',[logFolder 'OverviewDebug\'],...
    'saveYs',2*(length(json.overview.zDepts)>1),... Save some raw data ys if there are multiple depths
    'focusPositionInImageZpix',focusPositionInImageZpix,... No Z scan filtering
    'dispersionParameterA',dispersionParameterA,...
    'v',true);

%% Read processed volume and create an enface view
overviewVol = yOCTFromTif([output3DOverviewVolume(1:(end-1)) '_All.tif']); %Dimentions (z,x,y)
processedJson = awsReadJSON([output3DOverviewVolume 'processedScanConfig.json']);

xOverview = processedJson.xAllmm;
yOverview = processedJson.yAllmm;
zOverview = processedJson.zAllmm;

%Enface projection in Matlab prefers to work with matrix which is (y,x). So
%change dimentions to fit
overviewVol = permute(overviewVol,[1 3 2]); %(z,y,x)

%Make sure start and end are in the volume
zStart = max(zStart,1);
zEnd   = min(zEnd,size(overviewVol,1));

%Compute enface
enface = squeeze(max(overviewVol(zStart:zEnd,:,:))); %(y,x)

%Compute position of maximal z
depthOfMaxZ_pix = zeros(size(enface));
for i=1:size(depthOfMaxZ_pix,1)
    for j=1:size(depthOfMaxZ_pix,2) 
        o = overviewVol(zStart:zEnd,i,j);
    
        ii = find(o >= max(o)*1);
        depthOfMaxZ_pix(i,j) = median(ii);
    end
end

%% Correct enface for vineeting
%Our assumption s most of the scanning area is empty gel with no tissue
if false
    
    %Split enface to many small slices
    vv = mat2cell(enface,...
        json.overview.nYPixels*ones(length(json.overview.yCenters),1),...
        json.overview.nXPixels*ones(length(json.overview.xCenters),1));
    vm = zeros([size(vv{1}) numel(vv)]);
    
    %Calculate distortion
    for k=1:size(vm,3)
        vm(:,:,k) = vv{k};
    end
    vm = median(vm,3);

    %Correct for distortion
    for k=1:numel(vv)
        vv{k} = vv{k}./vm;
    end

    enface = cell2mat(vv); %Corrected version  
end

%% Compute principal axis and center of tissue
%Since image was scanned in ~45 degrees, find the angle that will re align
%it with the natural view

med = median(enface(:));
thershold =med*1.5;

%Find Principal Axis
[i,j] = find(enface > thershold); %x,y, positions of points which are 'tissue'
if ~isempty(i)
    V = pca([j,i]); %Main axis
    cxj = round(mean(j));
    cyi = round(mean(i));    
else
    disp('Warning: Could not determine orientation, using default 45 deg');
    V = sqrt(2)/2*[1 1; -1 1];
    cxj = round(size(enface,2)/2);
    cyi = round(size(enface,1)/2);
end
cx = xOverview(cxj);
cy = yOverview(cyi);

%Plot (debug)
imagesc(xOverview,yOverview,enface > thershold)
imagesc(xOverview,yOverview,enface)
hold on;
plot(cx+V(1)*1000*[-1,1],cy+V(2)*1000*[-1,1],'w');
hold off

%Rotation matrix
V_1 = V^-1;
ang = acos(V_1(1));
M = [cos(ang) sin(ang); -sin(ang) cos(ang)]; %Rotation matrix
Mc = M*[cx;cy];
Mcx = Mc(1);
Mcy = Mc(2);

%% Make the figure - Raw Data
figure(1); subplot(1,1,1);

%OCT Information
if isPlotEnface
    imagesc(xOverview,yOverview,enface);
    title('Enface View');
    colormap bone;
else
    imagesc(xOverview,yOverview,-depthOfMaxZ_pix);
    title('Depth of Max Intensity (Blue is deeper)');
    colormap parula
end
axis equal
xlabel('x[mm]');
ylabel('y[mm]');
grid on;
hold on;

%Create varibles with additional information for easy acess
lineLength = json.photobleach.lineLength;
vLinePositions = json.photobleach.vLinePositions;
hLinePositions = json.photobleach.hLinePositions;
scanRangeX = json.scan.rangeX;
scanRangeY = json.scan.rangeY;

%Plot the dot
theDot = [json.theDotX; json.theDotY];
theDot = theDot/norm(theDot)*lineLength/2*1.1;
plot(theDot(1),theDot(2),'bo','MarkerSize',10,'MarkerFaceColor','b','MarkerEdgeColor','w');

% Draw volume scan
volPos = [ ...
    +scanRangeX, -scanRangeX, -scanRangeX, +scanRangeX, +scanRangeX ; ... x
    +scanRangeY, +scanRangeY, -scanRangeY, -scanRangeY, +scanRangeY ; ... y
    ]/2; %mm
plot(volPos(1,:),volPos(2,:),'g--','LineWidth',2);

%Draw Lines V lines
for k=1:length(vLinePositions)
    vPos = [...
        vLinePositions(k) vLinePositions(k); ... x
        -lineLength/2 +lineLength/2; ... y
        ];    
    plot(vPos(1,:), vPos(2,:),'Color','r','LineWidth',2); %[x1,x2], [y1,y2]
end

%Draw Lines H lines
for k=1:length(hLinePositions)
    vPos = [...
        -lineLength/2 +lineLength/2; ... x
        hLinePositions(k) hLinePositions(k); ... y
        ];
    
    plot(vPos(1,:), vPos(2,:),'Color','r','LineWidth',1); %[x1,x2], [y1,y2]
end

%% Make the figure - Recomendations

%Set color for plots
if (isPlotEnface)
    c = 'w';
else
    c = 'w';
end

%Draw Sweet Spot, and where sectioning should start
st = histologyVolumeThickness/2*1e-3;%mm
dst = [0 0.5 1 1.5 2];
for i=1:2
    %Progress between the two line sets
    st = -st;
    dst = -dst;
    
    for j=1:length(dst)
        lStart = [-lineLength/2 ; st+dst(j)]; %(x,y)
        lEnd   = [+lineLength/2 ; st+dst(j)]; %(x,y)
        
        %Rotate
        lStart = M*lStart;
        lEnd   = M*lEnd;
        
        %Plot
        plot([lStart(1) lEnd(1)],[lStart(2) lEnd(2)],['--' c]);
        
        
        %Anotate
        if (lStart(1) > lEnd(1))
            lMax = lStart;
        else
            lMax = lEnd;
        end
        if j==1
            text(lMax(1),lMax(2),'Optimal','color',c);
        elseif mod(j,2)==1
            text(lMax(1),lMax(2),sprintf('+%.1fmm',abs(dst(j))),'color',c);
        end
    end
end

hold off;

%% Save figure
saveas(gcf,'Overview.png');
if (awsIsAWSPath(OCTVolumesFolder))
    %Upload to AWS
    awsCopyFileFolder('Overview.png',overviewOutputFolder);
else
    %Save locally
    saveas(gcf,overviewOutputFolder);
end   

