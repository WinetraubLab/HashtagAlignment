%This script stitches overview file

%% Inputs
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01/OCT Volumes/';
reconstructConfig = {'dispersionParameterA',6.539e07};%,'YFramesToProcess',1:5:100}; %Configuration for processing OCT Volume

%Probe Data
focusSigma = 20; %Sigma size of focus [pixel]

%Total width covered by histological sectioning 
histologyVolumeThickness = 15*5*(5+1); %[um]

%Low RAM mode
lowRAMMode = true; %When set to true, doesn't load all stitched volume to RAM, instead calculate enface in each worker

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
end
LogFolder = [OCTVolumesFolder '..\Log\02 OCT Preprocess\'];

%% Read Configuration file
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);

%Get dimensions
pixSizeX = json.overview.range * 1000/ json.overview.nPixels; % in microns
pixSizeY = pixSizeX;
gridXcc = json.overview.gridXcc;
gridYcc = json.overview.gridYcc;
gridXc = json.overview.gridXc;
gridYc = json.overview.gridYc;

scanRangeX = json.scan.rangeX;
scanRangeY = json.scan.rangeY;

%Define file path
fp = @(frameI)(sprintf('%s/Overview/Overview%02d/',OCTVolumesFolder,frameI));
fp = cellfun(fp,num2cell(1:length(gridXcc)),'UniformOutput',false)';

if ~isfield(json,'focusPositionInImageZpix')
    error('Please run findFocusInBScan before running this script');
else
    focusPositionInImageZpix = json.focusPositionInImageZpix;
end
%% Set start & Finish positions
zStart = max(focusPositionInImageZpix - focusSigma*5,1);
zEnd = min(focusPositionInImageZpix + focusSigma*7,1000);
%% Load overview images 
if lowRAMMode
    enface = cell(length(gridYc),length(gridXc));
else
    overviewScan = cell(length(gridYc),length(gridXc));
end
parfor i=1:length(gridXcc) %Because of the way the scan went we can easily stitch
    fprintf('%s Processing volume %d of %d.\n',datestr(datetime),i,length(gridYcc));
    
    fpTxt = fp{i};
    [int1,dim1] = ...
        yOCTLoadInterfFromFile([{fpTxt}, reconstructConfig]);
    [scan1,dim1] = yOCTInterfToScanCpx ([{int1 dim1},reconstructConfig]);
    scan1 = abs(scan1);
    for j=length(size(scan1)):-1:4 %Average BScan Averages, A Scan etc
        scan1 = squeeze(mean(scan1,j));
    end
    
    if lowRAMMode
        enface{i} = squeeze(mean(scan1(zStart:zEnd,:,:),1));
    else
        overviewScan{i} = shiftdim(scan1,1); %Dimensions are (x,y,z)
    end
end

if lowRAMMode
    enface = cell2mat(enface);
else
    overviewScan = cell2mat(overviewScan); %Convert to a big volume. (x,y,z)
    overviewScan = shiftdim(overviewScan,2); %Convert dimensions to (z,x,y)
    enface = squeeze(mean(overviewScan(zStart:zEnd,:,:),1));
end

%% Correct for any vineeting done by the lens
%Our assumption s most of the scanning area is empty gel with no tissue
vv = mat2cell(enface,...
     json.overview.nPixels*ones(length(gridYc),1),...
      json.overview.nPixels*ones(length(gridXc),1));
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

enface1 = cell2mat(vv); %Corrected version
clear enface; %Prevent confusion down the line

%% Create enfece, find principal axis of tissue
%Since image was scanned in ~45 degrees, find the angle that will re align
%it with the natural view

%Create grid
x = pixSizeX*( (-size(enface1,2)/2):(+size(enface1,2)/2) );
y = pixSizeY*( (-size(enface1,1)/2):(+size(enface1,1)/2) );

med = median(enface1(:));
thershold =med*1.5;

%Find Principal Axis
[i,j] = find(enface1 > thershold); %x,y, positions of points which are 'tissue'
if ~isempty(i)
    V = pca([j,i]); %Main axis
    cxj = round(mean(j));
    cyi = round(mean(i));    
else
    disp('Warning: Could not determine orientation, using default')
    V = diag([1 1]);
    cxj = round(size(enface1,2)/2);
    cyi = round(size(enface1,1)/2);
end
cx = x(cxj);
cy = y(cyi);

%Plot
imagesc(x,y,enface1 > thershold)
imagesc(x,y,enface1)
hold on;
plot(cx+V(1)*1000*[-1,1],cy+V(2)*1000*[-1,1],'w');
hold off

%% Move Enface and rotate
enface2 = imtranslate(enface1,-[cxj cyi]+size(enface1)/2,'FillValues',med);

%Compute what should be the inverse rotation such that V(:,1) will be
%facing X axis
V_1 = V^-1;
ang = acos(V_1(1));

%Rotate
enface3 = imrotate(enface2,ang*180/pi,'crop');
enface3(enface3 == 0) = med;

subplot(2,1,1);
imagesc(enface2)
subplot(2,1,2);
imagesc(enface3)

%% Make the figure
M = [cos(ang) sin(ang); -sin(ang) cos(ang)]; %Rotation matrix

figure(1); subplot(1,1,1);
imagesc(x,y,enface3)
xlabel('microns');
ylabel('microns');
colormap bone;
grid on;
hold on;

%Plot the dot
theDot = [1;-1];
theDot = theDot/norm(theDot)*1500;
theDot = M*(theDot-[cx;cy]); %Rotate, [um]
plot(theDot(1),theDot(2),'ro','MarkerSize',10,'MarkerFaceColor','r');

% Draw volume scan
volPos = [ ...
    +scanRangeX, -scanRangeX, -scanRangeX, +scanRangeX, +scanRangeX ; ... x
    +scanRangeY, +scanRangeY, -scanRangeY, -scanRangeY, +scanRangeY ; ... y
    ]/2; %mm
volPos = M*(volPos*1000-[cx;cy]); %Rotate, [um]
plot(volPos(1,:),volPos(2,:),'g--','LineWidth',2);

%Draw Lines V lines
for k=1:length(json.vLinePositions)
    vPos = [...
        json.vLinePositions(k) json.vLinePositions(k); ... x
        -json.lineLength/2 +json.lineLength/2; ... y
        ];
    vPos = M*(vPos*1000-[cx;cy]); %Rotate, [um]
    
    plot(vPos(1,:), vPos(2,:),'Color','r','LineWidth',2); %[x1,x2], [y1,y2]
end

%Draw Lines H lines
for k=1:length(json.hLinePositions)
    vPos = [...
        -json.lineLength/2 +json.lineLength/2; ... x
        json.hLinePositions(k) json.hLinePositions(k); ... y
        ];
    vPos = M*(vPos*1000-[cx;cy]); %Rotate, [um]
    
    plot(vPos(1,:), vPos(2,:),'Color','r','LineWidth',1); %[x1,x2], [y1,y2]
end

Mc = M*[cx;cy];
Mcx = Mc(1);
Mcy = Mc(2);
%Draw Sweet Spot, and where sectioning should start
st = histologyVolumeThickness/2;
dst = [0.5 1 1.5 2];
for i=1:2
    st = -st;
    dst = -dst;
    plot([-1000 1000]-Mcx,[st st]-Mcy,'--w');
    text(1000-Mcx,st-Mcy,'Optimal','color','w')
    for j=1:length(dst)
        plot([-1000 1000]-Mcx,[st st]+dst(j)*1000-Mcy,'--w');
        if mod(j,2)==0
            text(1000-Mcx,st+dst(j)*1000-Mcy,sprintf('+%.1fmm',abs(dst(j))),'color','w');
        end
    end
end

hold off;

%% Save figure
if (awsIsAWSPath(OCTVolumesFolder))
    %Upload to AWS
    saveas(gcf,'Overview.png');
    awsCopyFileFolder('Overview.png',[LogFolder '/Overview.png']);
else
    %Save locally
    if ~exist(LogFolder,'dir')
        mkdir(LogFolder)
    end
    saveas(gcf,[LogFolder '\Overview.png']);
end   

