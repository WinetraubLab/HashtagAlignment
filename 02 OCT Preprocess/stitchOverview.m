%This script stitches overview file

%% Inputs
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-00/OCT Volumes/';
reconstructConfig = {'dispersionParameterA',6.539e07,'YFramesToProcess',1:10:100}; %Configuration for processing OCT Volume

%Probe Data
focusSigma = 20; %Sigma size of focus [pixel]

%topskip
zStart = 200;%Skip first pixels as they have artifact in them

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
pixSizeY = pixSizeX*10;
gridXcc = json.overview.gridXcc;

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

%Create enface
enface = squeeze(mean(overviewScan(zStart:end,:,:),1));

%% Rotate Enface
%Since image was scanned in ~45 degrees, find the angle that will re align
%it with the natural view

thershold = 0.5;
[y,x] = find(enface > thershold); %x,y, positions of points which are 'tissue'
V = pca([x,y]); %Main axis
v1 = V(:,1); 
v2 = V(:,2);



%% 
log(squeeze(mean(exp(stitched(topskip:end,:,:)),1))); colormap(gray)
    
    %Create a map grid, which overview goes where
%map = zeros(

%%
[x,y] = meshgrid(1:4,1:4);
x=y;
%xx = zeros(2,2,length(x(:)));
xx = cell(4,4);
for i=1:numel(xx)
    %xx(:,:,i) = x(i);
    xx{i} = ones(3,3,2)*x(i);
end
%reshape(xx,4*2,4*2)
cell2mat(xx)
