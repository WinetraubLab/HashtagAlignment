%This script finds the position of the focus in the B scan image 
%(for stitching)

disp('Looking For Focus Position...');
%% Inputs

%OCT Data
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-00/OCT Volumes/';
reconstructConfig = {'dispersionParameterA',6.539e07}; %Configuration for processing OCT Volume

%Probe Data
focusSigma = 20; %Sigma size of focus [pixel]

%% Jenkins
if (isRunningOnJenkins() || exist('runninAll','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
end

%% Read Configuration file
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);
zToScan = json.zToScan;
n = json.tissueRefractiveIndex; 

%Define file path
OCTVolumesFolderVolume = [OCTVolumesFolder '/Volume/'];
fp = @(frameI)(sprintf('%sPos%02d/',OCTVolumesFolderVolume,frameI));

%Get Dimensions of one reference volume
dim = yOCTLoadInterfFromFile(fp(1),'peakOnly',true);
dim.x.units = 'microns';
dim.x.values = 1000* linspace(-json.scan.rangeX/2,json.scan.rangeX/2,length(dim.x.values));
dim.y.values = 1000* linspace(-json.scan.rangeY/2,json.scan.rangeY/2,length(dim.x.values));
dim.y.units = 'microns';

%Load a few y slices
yToLoad = dim.y.index(...
    round(linspace(1,length(dim.y.index),5)) ...
    );

%% Use frame where focus is at tissue to make an initial guess of where focus is in B Scan
frameI = find(zToScan == 0,1,'first');

%Load a few y slices
[int1,dim1] = ...
    yOCTLoadInterfFromFile([{fp(frameI)}, reconstructConfig, {'YFramesToProcess',yToLoad}]);
[scan1,dim1] = yOCTInterfToScanCpx ({int1 dim1 ,'n',n});
scan1 = abs(scan1);
for i=length(size(scan1)):-1:4 %Average BScan, AScan avg but no z,x,y
    scan1 = squeeze(mean(scan1,i));
end
dim.z = dim1.z; %Update dimensions structure

%Find tissue position by maximum intensity
figure(1);
tissueZi = zeros(size(scan1,3),1); %Tissue depth for each scan
for i=1:length(tissueZi)
    scan = squeeze(scan1(:,:,i));
    
    %Find maximum
    tissueZi(i) = find(median(scan,2) == max(median(scan,2)),1,'first');
    
    %Plot    
    if (i<=4)
        subplot(2,2,i);
        imagesc(dim.x.values,dim.z.values,log(scan))
        colormap gray
        hold on;
        fd =  dim.z.values(tissueZi(i));
        plot(dim.x.values([1 end]),fd*[1 1],'--');
        hold off;
        title(sprintf('y=%.2f',dim1.y.values(i)));
        xlabel(['x [' dim.x.units ']'])
        ylabel(['z [' dim.z.units ']'])
    end
end

focusDepth1 = mean(dim.z.values(tissueZi)); %[um] - first guess

%% Refine initial guess by going to the point where focus is highest
frameI = 1;

[int1,dim1] = ...
    yOCTLoadInterfFromFile([{fp(frameI)}, reconstructConfig, {'YFramesToProcess',yToLoad}]);
[scan1,dim1] = yOCTInterfToScanCpx ({int1 dim1 ,'n',n});
scan1 = abs(scan1);
for i=length(size(scan1)):-1:4 %Average BScan, AScan avg but no z,x,y
    scan1 = squeeze(mean(scan1,i));
end

%Define search space
zsToUse = dim.z.values > focusDepth1 - focusSigma & dim.z.values < focusDepth1 + focusSigma;

%% For each y, compute how close it is (in intensity) to other ys. 
%In theory only the gel with the focus should be visible so some y sections
%should be very close to each other
m1 = squeeze(median(scan1,2)); %Median over x

%Distance matrix
d = pdist(m1'); %Distance matrix, for easy visualization do squareform(d)
Z = linkage(d); %Cluster
nClusters = round(size(m1,2)*0.6); %Number of clusters output
c = cluster(Z,'maxclust',nClusters); %Split into clusters

%Measure size of each cluster
cNumbers = unique(c);
cSize = zeros(size(cNumbers));
for i=1:length(cNumbers)
    cSize(i) = sum(c==i);
end
cLargest = cNumbers(cSize==max(cSize));
ysToUse = c==cLargest;

%Average
m2 = mean(m1(:,ysToUse),2);
m2 = imgaussfilt(m2,4); %Apply Gaussian filtering

%Find z corresponding to maximum - that is the focus
tmp1 = dim.z.values(zsToUse);
tmp2 = m2(zsToUse);
focusDepth2 = tmp1(tmp2==max(tmp2)); %[um] - 2nd guess

figure(2);
plot(dim.z.values(zsToUse),[m1(zsToUse,ysToUse)])
hold on;
plot(dim.z.values(zsToUse),m2(zsToUse),'k--')
plot(focusDepth2,m2(dim.z.values == focusDepth2),'o')
hold off;

%% Plot and let the user decide
%Find focal point as the brightest (its also the top of the tissue..)
ax = figure(4);
imagesc(dim.x.values,dim.z.values,squeeze(log(mean(scan1,3))))
colormap gray
hold on;
plot(dim.x.values([1 end]),focusDepth1*[1 1],'--');
plot(dim.x.values([1 end]),focusDepth2*[1 1],'--');
hold off;
xlabel(['x [' dim.x.units ']'])
ylabel(['z [' dim.z.units ']'])
title('Choose focus');
legend('First Guess','Updated Guess');

if (~isRunningOnJenkins())
    [~,focusDepth3] = ginput(1); %Get z index of the focus
    fprintf('Distance between my guess and user: %.1f[um]\n',abs(focusDepth3-focusDepth2));
    
    hold on
    plot(dim.x.values([1 end]),focusDepth3*[1 1],'--');
    legend('First Guess','Updated Guess','User Input');
    hold off;
else
    focusDepth3 = focusDepth2;
end

fprintf('Initial guess: %.1f[um]\n',focusDepth1);
fprintf('Updated guess: %.1f[um]\n',focusDepth2);
if (~isRunningOnJenkins())
    fprintf('User input: %.1f[um]\n',focusDepth3);
end

%% Output & Save
%Output Tiff 
saveas(ax,'FindFocusInBScan.png');

%Update JSON
%json.focusPositionInImageZum = focusDepth3;
dz = abs(focusDepth3-dim.z.values);
json.focusPositionInImageZpix = find(dz == min(dz),1,'first');
json.VolumeOCTDimensions = dim;
awsWriteJSON(json,[OCTVolumesFolder 'ScanConfig.json']);