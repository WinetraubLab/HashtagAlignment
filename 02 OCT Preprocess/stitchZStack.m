%This script stitches images aquired at different z depths 2gezer

%OCT Data
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01/OCTVolumes/';
reconstructConfig = {'dispersionParameterA',6.539e07}; %Configuration for processing OCT Volume

%Probe Data
focusSigma = 20; %Sigma size of focus [pixel]

%Save Some Intermediate Y Scans
saveYs = 3; %How many Bscans to save (for future reference)

%Low memory mode, save results to a Tiff remotely than gather them all at
%the very end

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
end

%Find subject folder by removing last folder
tmp = awsModifyPathForCompetability(OCTVolumesFolder);
tmp = fliplr(tmp);
i = [find(tmp(2:end)=='/',1,'first'),find(tmp(2:end)=='\',1,'first')]; %Hopefully one is empty and the other contain the data
tmp(1:min(i)) = [];
SubjectFolder = fliplr(tmp);

%% Read Configuration
json = awsReadJSON([OCTVolumesFolder 'ScanConfig.json']);
if ~isfield(json,'focusPositionInImageZpix')
    error(sprintf('Prior to running stitching, you need to find the position of the focus in the stack\n run findFocusInBScan script'));
end
zToScan = json.zToScan;
n = json.tissueRefractiveIndex; 
focusPositionInImageZpix = json.focusPositionInImageZpix;

%Define file path
fp = @(frameI)(sprintf('%s/Volume/Pos%02d/',OCTVolumesFolder,frameI));
fp = cellfun(fp,num2cell(1:length(zToScan)),'UniformOutput',false)';

%Get dimensions
dim = json.VolumeOCTDimensions;

%Save some Ys
yToSave = dim.y.index(...
    round(linspace(1,length(dim.y.index),saveYs)) ...
    );
yToSave = []; %Dont save <--

pixSizeZ = diff(dim.z.values([1 2])); %um

OCTSystem = [json.OCTSystem '_SRR']; %Provide OCT system to prevent unesscecary polling of file system
[dimensions] = ...
            yOCTLoadInterfFromFile([fp{1}, reconstructConfig, {'OCTSystem',OCTSystem,'peakOnly',true}]);

%% Prepeaere to log
LogFolder = awsModifyPathForCompetability([SubjectFolder '\Log\02 OCT Preprocess\']);
if ~awsIsAWSPath(LogFolder) && ~exist(LogFolder,'dir')
    mkdir(LogFolder);
end

%In debug mode, we shall save all temporary files 
isRunInDebugMode = false;
if (exist('isRunInDebugMode_','var'))
    isRunInDebugMode = isRunInDebugMode_;
end

%% Preform stitching
fprintf('%s Stitching ...\n',datestr(datetime)); tt=tic();

%Set up for paralel processing
yIndexes=dim.y.index;
thresholds = zeros(length(yIndexes),1);
cValues = zeros(length(yIndexes),2);
imOutSize = [length(dim.z.values) length(dim.x.values) length(yIndexes)]; %z,x,y

%Make sure a temporary folder to save the data is empty
dirToSaveProcessedYFrames = [OCTVolumesFolder '/yFrames_db/'];
awsRmDir(dirToSaveProcessedYFrames);

if ~isempty(yToSave)
    dirToSaveStackDemos = [OCTVolumesFolder '/SomeStacks_db/'];
    awsRmDir(dirToSaveStackDemos);
end

setupParpolOCTPreprocess();

%Loop over y frames
printStatsEveryyI = floor(length(yIndexes)/20);
ticBytes(gcp);
parfor yI=1:length(yIndexes)
    try
    if mod(yI,printStatsEveryyI)==0
        %Stats time!
        %fprintf('%s Processing yIndex=%d (yI=%d of %d).\n',datestr(datetime),yIndexes(yI),yI,length(yIndexes)); %#ok<PFBNS>
        ds = fileDatastore(dirToSaveProcessedYFrames,'ReadFcn',@(x)(x),'FileExtensions','.mat'); %Count all artifacts
        done = length(ds.Files);
        fprintf('%s So far, completed yIs: %d/%d (%.1f%%)\n',datestr(datetime),done,length(yI),100*done/length(yI));
    end
    
    %Loop over depths
    stack = zeros([imOutSize(1:2), length(zToScan)])*NaN; %#ok<PFBNS> %z,x,zStach
    for zzI=1:length(zToScan)
        
        %Load Frame
        fpTxt = fp{zzI};
        [int1,dim1] = ...
            yOCTLoadInterfFromFile([{fpTxt}, reconstructConfig, {'dimensions',dimensions, 'YFramesToProcess',yIndexes(yI)}]);
        [scan1,dim1] = yOCTInterfToScanCpx ([{int1 dim1} reconstructConfig]);
        int1 = []; %Freeup some memory
        scan1 = abs(scan1);
        for i=length(size(scan1)):-1:3 %Average BScan Averages, A Scan etc
            scan1 = squeeze(mean(scan1,i));
        end
        
        %Filter
        zI = 1:length(scan1); zI = zI(:);
        factor = repmat(exp(-(zI-focusPositionInImageZpix).^2/(2*focusSigma)^2), [1 size(scan1,2)]);
          
        %Add to stack
        stack(:,:,zzI) = imtranslate((scan1.*factor),[0,zToScan(zzI)/pixSizeZ],'FillValues',NaN); 
            %In translation, compensate for water/tissue numerical
            %apperature
    end
    
    %Since we are dealing with a log scale, its important to trim the image
    %Let us trim the image using the signal at the gel (top of the image)
    tmp = nanmedian(squeeze(stack(:,:,1)),2);
    th = max(tmp(:))/size(stack,3)/2; %Devided by the amount of averages
    c = [prctile(tmp(:),20), prctile(tmp(:),99.9)];
    
    %Save Stack, some files for future reference
    if (sum(yIndexes(yI) == yToSave)>0)
        tn = [tempname '.mat'];
        yOCT2Mat(stack,tn)
        awsCopyFile_MW1(tn, ...
            awsModifyPathForCompetability(sprintf('%s/y%04dZStack_db.mat',dirToSaveStackDemos,yIndexes(yI))) ...
            );
        delete(tn);
    end
    
    %Compute stacked frame
    stackmean = squeeze(single(nanmean(stack,3))); 
    stack = []; %Clear memory
    
    %Save results to temporary files to be used later (once we know the
    %scale of the images to write
    tn = [tempname '.mat'];
    yOCT2Mat(stackmean,tn)
    awsCopyFile_MW1(tn, ...
        awsModifyPathForCompetability(sprintf('%s/y%04d.mat',dirToSaveProcessedYFrames,yIndexes(yI)))...
        ); %Matlab worker version of copy files
    delete(tn);
    
    %Save thresholds, this data is small so we can send it back
    thresholds(yI) = th;
    cValues(yI,:) = c;
         
    catch ME
        fprintf('Error happened in parfor, iteration %d, yIndex: %d\n',yI,yIndexes(yI)); 
        disp(ME.message);
        for j=1:length(ME.stack) 
            ME.stack(j) 
        end  
        error('Error in parfor');
    end
end
fprintf('Done stitching, toatl time: %.0f[min]\n',toc(tt)/60);
tocBytes(gcp)

%% Reorganizing files
fprintf('% Reorg files ... ',datestr(datetime));
tt=tic;
if (isRunInDebugMode)
    %Only reorg if we run in debug mode, otherwise don't bother
    awsCopyFile_MW2(dirToSaveProcessedYFrames);
end
if ~isempty(yToSave)
    awsCopyFile_MW2(LogFolder); %For the ys that are saved
end
fprintf('Done! took %.0f[min]\n',toc(tt)/60);

%% Threshlod
%Compute a single threshold for all files
th = single(mean(thresholds));

%% Collect all mat files from datastore to create a single output
disp('Saving to Tiff ...');
tt=tic;
ticBytes(gcp);
%Read (using parpool)
bv = yOCTReadBigVolume(dirToSaveProcessedYFrames,'mat');

%Apply threshold
bv(bv<th) = th;
bv = log(bv);

%Write (using parpool)
location = awsModifyPathForCompetability([OCTVolumesFolder '/VolumeScanAbs/'],false);
yOCTWriteBigVolume(bv,dim, location,'tif',log(mean(cValues)));
fprintf('Done saving sa a big volume, toatl time: %.0f[min]\n',toc(tt)/60);
tocBytes(gcp)

%% Save overviews of a few Y sections to log
if ~isempty(yToSave)
    yStackPath = cell(size(yToSave(:)));
    for i=1:length(yToSave)
        yStackPath{i} = sprintf('%s/y%04d.',dirToSaveStackDemos,yToSave(i));
    end

    parfor i=1:length(yToSave)
        im = yOCTFromTif([yStackPath{i} 'mat']);

        im(im<th) = th;

        tn = [tempname '.tif'];
        yOCT2Tif(log(im),tn,log(cValues(i,:))); %Save to temp file
        awsCopyFile_MW1(tn, yStackPath{i}); %Matlab worker version of copy files
    end
    awsCopyFile_MW2(LogFolder); %Finish the job
end

%% Cleanup temporary files and debugs
if ~isRunInDebugMode
    awsRmDir(dirToSaveProcessedYFrames);  
    if ~isempty(yToSave)
        awsRmDir(dirToSaveStackDemos);
    end
else
    yOCT2Mat(thresholds,[LogFolder '/thresholds_db.mat']);
    yOCT2Mat(cValues,[LogFolder '/cValues_db.mat']);
end