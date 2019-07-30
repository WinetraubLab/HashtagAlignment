%This script stitches overview file
return;
%% Inputs
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-00/OCT Volumes/';
reconstructConfig = {'dispersionParameterA',6.539e07};%,'YFramesToProcess',1:5:100}; %Configuration for processing OCT Volume

%Probe Data
focusSigma = 20; %Sigma size of focus [pixel]

%topskip
zStart = 200;%Skip first pixels as they have artifact in them

%Total width covered by histological sectioning 
histologyVolumeThickness = 15*5*(5+1); %[um]

%% Jenkins
if (isRunningOnJenkins() || exist('runninAll','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
end

%% Read Configuration file
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);

%Define file path
fp = @(frameI)(sprintf('%s/Overview/Overview%02d/',OCTVolumesFolder,frameI));

%Get dimensions
pixSizeX = json.overview.range * 1000/ json.overview.nPixels; % in microns
pixSizeY = pixSizeX*1;%5; %<--TMP
gridXcc = json.overview.gridXcc;

scanRangeX = json.scan.rangeX;
scanRangeY = json.scan.rangeY;

%% Load overview images 
overviewScan = cell(length(json.overview.gridXc),length(json.overview.gridYc));
parfor i=1:length(gridXcc) %Because of the way the scan went we can easily stitch
    fprintf('%s Processing volume %d of %d.\n',datestr(datetime),i,length(gridXcc));
    
    fpTxt = feval(fp,i);
    [int1,dim1] = ...
        yOCTLoadInterfFromFile([{fpTxt}, reconstructConfig]);
    [scan1,dim1] = yOCTInterfToScanCpx ([{int1 dim1},reconstructConfig]);
    scan1 = abs(scan1);
    for j=length(size(scan1)):-1:4 %Average BScan Averages, A Scan etc
        scan1 = squeeze(mean(scan1,j));
    end
    
    overviewScan{i} = shiftdim(scan1,1); %Dimensions are (x,y,z)
end
overviewScan = cell2mat(overviewScan); %Convert to a big volume. (x,y,z)
overviewScan = shiftdim(overviewScan,2); %Convert dimensions to (z,x,y)

%% Create enfece, find principal axis of tissue
%Since image was scanned in ~45 degrees, find the angle that will re align
%it with the natural view

%Create enface
enface = squeeze(mean(overviewScan(zStart:end,:,:),1));
x = pixSizeX*( (-size(enface,2)/2):(+size(enface,2)/2) );
y = pixSizeY*( (-size(enface,1)/2):(+size(enface,1)/2) );

%enface = enface(1:5:end,:); %<--TMP
thershold = mean(mean(mean(overviewScan(zStart+(1:10),:,:))))*1.1;

imagesc(enface > thershold)

%Find Principal Axis
[i,j] = find(enface > thershold); %x,y, positions of points which are 'tissue'
V = pca([j,i]); %Main axis
ang = -acos(V(1)); %Angle to rotate

%% Make the figure
M = [cos(ang) sin(ang); -sin(ang) cos(ang)]; %Rotation matrix
enfacerot = imrotate(enface,ang*180/pi,'crop');
enfacerot(enfacerot == 0) = thershold;

imagesc(x,y,log(enfacerot))
xlabel('microns');
ylabel('microns');
colormap bone;
grid on;
hold on;

% Draw volume scan
volPos = [ ...
    +scanRangeX, -scanRangeX, -scanRangeX, +scanRangeX, +scanRangeX ; ... x
    +scanRangeY, +scanRangeY, -scanRangeY, -scanRangeY, +scanRangeY ; ... y
    ]/2; %mm
volPos = M*volPos*1000; %Rotate, [um]
plot(volPos(1,:),volPos(2,:),'g--','LineWidth',2);

%Draw Lines V lines
for k=1:length(json.vLinePositions)
    vPos = [...
        json.vLinePositions(k) json.vLinePositions(k); ... x
        -json.lineLength/2 +json.lineLength/2; ... y
        ];
    vPos = M*vPos*1000; %Rotate, [um]
    
    plot(vPos(1,:), vPos(2,:),'Color','r','LineWidth',2); %[x1,x2], [y1,y2]
end

%Draw Lines H lines
for k=1:length(json.hLinePositions)
    vPos = [...
        -json.lineLength/2 +json.lineLength/2; ... x
        json.hLinePositions(k) json.hLinePositions(k); ... y
        ];
    vPos = M*vPos*1000; %Rotate, [um]
    
    plot(vPos(1,:), vPos(2,:),'Color','r','LineWidth',1); %[x1,x2], [y1,y2]
end

%Draw Sweet Spot, and where sectioning should start
st = histologyVolumeThickness/2;
dst = [0.5 1 1.5 2];
for i=1:2
    st = -st;
    dst = -dst;
    plot([-1000 1000],[st st],'--w');
    text(1000,st,'Optimal','color','w')
    for j=1:length(dst)
        plot([-1000 1000],[st st]+dst(j)*1000,'--w');
        if mod(j,2)==0
            text(1000,st+dst(j)*1000,sprintf('+%.1fmm',abs(dst(j))),'color','w');
        end
    end
end

hold off;

%% Save figure
if (strcmpi(OCTVolumesFolder(1:3),'s3:'))
    %Upload to AWS
    OCTVolumesFolder = awsModifyPathForCompetability(OCTVolumesFolder,false);
    saveas(gcf,'Overview.png');
    awsCopyFileFolder('Overview.png',[OCTVolumesFolder '/Overview.png']);
else
    %Save locally
    saveas(gcf,[OCTVolumesFolder '/Overview.png']);
end

