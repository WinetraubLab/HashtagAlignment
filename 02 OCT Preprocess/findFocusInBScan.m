%This script finds the position of the focus in the B scan image 
%(for stitching)

disp('Looking For Focus Position...');
%% Inputs

%OCT Data
OCTVolumesFolder = [s3SubjectPath('12','LHC') 'OCTVolumes/'];
reconstructConfig = {'dispersionQuadraticTerm',6.539e07}; %Configuration for processing OCT Volume

%Probe Data
focusSigma = 20; %Sigma size of focus [pixel]

isRunInAutomatedMode =  false;

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
end
LogFolder = [OCTVolumesFolder '..\Log\02 OCT Preprocess\'];

if (exist('isRunInAutomatedMode_','var'))
    isRunInAutomatedMode = isRunInAutomatedMode_;
end

%% Read Configuration file
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);

if (isfield(json,'focusPositionInImageZpix') && isRunInAutomatedMode)
    disp('Focus was found already, will not atempt finding focus again in Automatic Mode');
    return; %Don't try to focus again, only in manual mode
end

if isfield(json.volume,'tissueRefractiveIndex')
    n = json.volume.tissueRefractiveIndex; 
elseif isfield(json.overview,'tissueRefractiveIndex')
    n = json.overview.tissueRefractiveIndex; 
else
    warning('Can''t figure out what is index of refraction, assuming default value');
    n = 1.33;
end

%% Find a scan that was done when tissue was at focus (z=0)
%Decide wheter to use scan or overview for findig focus
if isfield(json.volume,'zDepths')
    findFocusByUsing = 'volume';
    zDepths = json.volume.gridZcc; 
    
    %Find the frame to be used 
    frameI = find(abs(zDepths) == min(abs(zDepths)),1,'first'); %Find the one closest to 0
    
    %Define a path by frame
    OCTVolumesFolderVolume = [OCTVolumesFolder '/Volume/'];
    fp = sprintf('%sData%02d/',OCTVolumesFolderVolume,frameI);
    
    %Define range
    xRange = json.volume.xRange;
    yRange = json.volume.yRange;

elseif isfield(json.overview,'zDepths')
    findFocusByUsing = 'overview';
    zDepths = json.overview.gridZcc;
    
    %Find the frame to be used 
    frameI = find(abs(zDepths) == min(abs(zDepths)),1,'first'); %Find the one closest to 0
    
    %Define a path by frame
    OCTVolumesFolderVolume = [OCTVolumesFolder '/Overview/'];
    fp = sprintf('%sData%02d/',OCTVolumesFolderVolume,frameI);
    
    %Define range
    xRange = json.overview.range;
    yRange = json.overview.range;
end

%% Get peak data
%Get Dimensions of one reference volume'
[dim, dimProcessed] = yOCTTileScanGetDimOfOneTile(OCTVolumesFolderVolume, 'micron');

%Load a few y slices
yToLoad = dim.y.index(...
    round(linspace(1,length(dim.y.index),5)) ...
    );

%% Use frame where focus is at tissue to make an initial guess of where focus is in B Scan

%Load a few y slices
[int1,dim1] = ...
    yOCTLoadInterfFromFile([{fp}, reconstructConfig, {'dimensions', dim,'YFramesToProcess',yToLoad}]);
[scan1,dim1] = yOCTInterfToScanCpx ([{int1, dim1, 'n', n}, reconstructConfig]);

% Take the absolute value of the slices and apply any A-scan and/or B-scan
% averaging
scan1 = yOCTApplyAbsoluteValueAScanBScanAveraging(scan1);

dim.z = dim1.z; %Update dimensions structure

% Optical Path Correction
scanInfoJson = awsReadJSON([OCTVolumesFolderVolume 'ScanInfo.json']);
[scan1, scan1ValidDataMap] = yOCTOpticalPathCorrection(scan1, dim1, scanInfoJson);

%Compute the total travel distance of the scanning process
totalZDistance = diff(zDepths([1 end]))*1000; %mu
totalZDistanceI = totalZDistance/diff(dim.z.values([1 2])); %pixels

%Find tissue position by maximum intensity
figure(1);
tissueZi = zeros(size(scan1,3),1); %Tissue depth for each scan
for i=1:length(tissueZi)
    scan = squeeze(scan1(:,:,i));
    
    %Find maximum
    medScan = median(scan,2);
    medScan(1:round(0.5*totalZDistanceI)) = NaN; %Its unlikely that the focus point will be at the top part, as traveling will make the 'wrap around problem'
    tissueZi(i) = find(medScan == max(medScan),1,'first');
    
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
        pause(0.1)
    end
end

focusDepth1 = median(dim.z.values(tissueZi)); %[um] - first guess

%% Refine initial guess by going to the point where focus is highest
disp('Refining Focus Position...');

% Find index of the top of the gel, but not the very top, one section
% deeper.
[~,ii] = sort(zDepths,'ascend'); % Sort from top of the gel to deepest part of the section
frameI = ii(2); %frame = ii(1) is at the top of the gel, number ii(2) should be better
fp = sprintf('%sData%02d/',OCTVolumesFolderVolume,frameI);

[int1,dim1] = ...
    yOCTLoadInterfFromFile([{fp}, reconstructConfig, {'dimensions', dim, 'YFramesToProcess',yToLoad}]);
[scan1,dim1] = yOCTInterfToScanCpx ([{int1, dim1, 'n', n}, reconstructConfig]);

% Take the absolute value of the slices and apply any A-scan and/or B-scan
% averaging
scan1 = yOCTApplyAbsoluteValueAScanBScanAveraging(scan1);

% Optical Path Correction
[scan1, scan1ValidDataMap] = yOCTOpticalPathCorrection(scan1, dim1, scanInfoJson);

%Define search space
zsToUse = dim.z.values > focusDepth1 - focusSigma*2 & dim.z.values < focusDepth1 + focusSigma*2;

%% For each y, compute how close it is (in intensity) to other ys. 
%In theory only the gel with the focus should be visible so some y sections
%should be very close to each other
m1 = squeeze(median(scan1,2)); %Median over x

%Distance matrix
d = pdist(m1'); %Distance matrix, for easy visualization do squareform(d)
Z = linkage(d); %Cluster
figure(2);
dendrogram(Z)
nClusters = round(size(m1,2)*0.6); %Number of clusters output
c = cluster(Z,'maxclust',nClusters); %Split into clusters

%Measure size of each cluster
cNumbers = unique(c);
cSize = zeros(size(cNumbers));
for i=1:length(cNumbers)
    cSize(i) = sum(c==i);
end
cLargest = cNumbers(find(cSize==max(cSize),1,'first'));
ysToUse = c==cLargest;

%Average
m2 = mean(m1(:,ysToUse),2);
m2 = imgaussfilt(m2,4); %Apply Gaussian filtering

%Find z corresponding to maximum - that is the focus
tmp1 = dim.z.values(zsToUse);
tmp2 = m2(zsToUse);
focusDepth2 = tmp1(tmp2==max(tmp2)); %[um] - 2nd guess

figure(3);
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
if (zDepths(frameI) < 0)
    title(sprintf('Choose focus\nShould be about %.0fum above average gel-tissue interface',1000*abs(zDepths(frameI))));
else
    title(sprintf('Choose focus\nShould be about %.0fum below average gel-tissue interface',1000*abs(zDepths(frameI))));
end
legend('First Guess','Updated Guess');

if (~isRunInAutomatedMode)
    %Manual mode, ask user to refine
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
if (~isRunInAutomatedMode)
    fprintf('User input: %.1f[um]\n',focusDepth3);
end

%% Output & Save

%Update JSON
%json.focusPositionInImageZum = focusDepth3;
dz = abs(focusDepth3-dim.z.values);
json.focusPositionInImageZpix = find(dz == min(dz),1,'first');
json.VolumeOCTDimensions = dim;
awsWriteJSON(json,[OCTVolumesFolder 'ScanConfig.json']); %Can save locally or to AWS

%Output Tiff 
saveas(ax,'FindFocusInBScan.png');
if (awsIsAWSPath(OCTVolumesFolder))
    %Upload to AWS
    awsCopyFileFolder('FindFocusInBScan.png',[LogFolder '/FindFocusInBScan.png']);
else
    if ~exist(LogFolder,'dir')
        mkdir(LogFolder)
    end
    copyfile('FindFocusInBScan.png',[LogFolder '\FindFocusInBScan.png']);
end   