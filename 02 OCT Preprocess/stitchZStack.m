%This script stitches images aquired at different z depths 2gezer

%OCT Data
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01/OCTVolumes/';
reconstructConfig = {'dispersionParameterA',6.539e07}; %Configuration for processing OCT Volume

%Probe Data
focusSigma = 20; %Sigma size of focus [pixel]

%Save Some Intermediate Y Scans
saveYs = 3; %How many Bscans to save (for future reference)

%When executing this file, would you like to work in debug mode?
isRunInDebugMode = true; %In debug mode, we shall save all temporary files 
isLoadFromDebugModeAfterPreProcessing = true; %When set to true, will skip processing and just load current state from debug loads

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
    
    %Usually when running from a runner, don't want to work in debug mode
    isRunInDebugMode = false; 
    isLoadFromDebugModeAfterPreProcessing = false;
end
if (exist('isRunInDebugMode_','var'))
    isRunInDebugMode = isRunInDebugMode_;
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
%zToScan = json.zToScan(1:10:end); %<-- speed things up (1:10:end)
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

pixSizeZ = diff(dim.z.values([1 2])); %um

OCTSystem = [json.OCTSystem '_SRR']; %Provide OCT system to prevent unesscecary polling of file system
[dimensions] = ...
            yOCTLoadInterfFromFile([fp{1}, reconstructConfig, {'OCTSystem',OCTSystem,'peakOnly',true}]);
        
%% Set up for paralel processing
yIndexes=dim.y.index;
thresholds = zeros(length(yIndexes),1);
cValues = zeros(length(yIndexes),2);
imOutSize = [length(dim.z.values) length(dim.x.values) length(yIndexes)]; %z,x,y

%Directory structure
dirToSaveProcessedYFrames = awsModifyPathForCompetability([OCTVolumesFolder '/yFrames_db/']);
dirToSaveStackDemos = awsModifyPathForCompetability([OCTVolumesFolder '/SomeStacks_db/']);
tiffOutputFolder = awsModifyPathForCompetability([OCTVolumesFolder '/VolumeScanAbs/']);
LogFolder = awsModifyPathForCompetability([SubjectFolder '\Log\02 OCT Preprocess\']);

if ~isLoadFromDebugModeAfterPreProcessing
%% Prepeaere to log
if ~awsIsAWSPath(LogFolder) && ~exist(LogFolder,'dir')
    mkdir(LogFolder);
end

%% Preform stitching
fprintf('%s Stitching ...\n',datestr(datetime)); tt=tic();

%Make sure a temporary folder to save the data is empty
awsRmDir(dirToSaveProcessedYFrames);
if ~isempty(yToSave)
    awsRmDir(dirToSaveStackDemos);
end

setupParpolOCTPreprocess();

%Loop over y frames
printStatsEveryyI = floor(length(yIndexes)/20);
ticBytes(gcp);
parfor yI=1:length(yIndexes)
    try
    %fprintf('%s Processing yIndex=%d (yI=%d of %d).\n',datestr(datetime),yIndexes(yI),yI,length(yIndexes)); %#ok<PFBNS>        
    
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
    c = [prctile(tmp(:),20), prctile(tmp(:),99.99)];
    
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
    
    %Is it time to print statistics?
    if mod(yI,printStatsEveryyI)==0
        %Stats time!
        ds = fileDatastore(dirToSaveProcessedYFrames,'ReadFcn',@(x)(x),'FileExtensions','.getmeout','IncludeSubfolders',true); %Count all artifacts
        done = length(ds.Files);
        fprintf('%s Completed yIs so far: %d/%d (%.1f%%)\n',datestr(datetime),done,length(yIndexes),100*done/length(yIndexes));
    end
         
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
fprintf('%s Reorg files ... ',datestr(datetime));
tt=tic;
if (isRunInDebugMode)
    %Only reorg if we run in debug mode, otherwise don't bother
    awsCopyFile_MW2(dirToSaveProcessedYFrames);
end
if ~isempty(yToSave)
    awsCopyFile_MW2(dirToSaveStackDemos); %For the ys that are saved
end
fprintf('Done! took %.1f[min]\n',toc(tt)/60);

if isRunInDebugMode
    %Save some overviews
    yOCT2Mat(thresholds,[LogFolder '/thresholds_db.mat']);
    yOCT2Mat(cValues,[LogFolder '/cValues_db.mat']);
end

%% Loading from debug mode
else %isLoadFromDebugModeAfterPreProcessing
    thresholds = yOCTFromMat([LogFolder '/thresholds_db.mat']);
    cValues = yOCTFromMat([LogFolder '/cValues_db.mat']);
end

%% Threshlod
%Compute a single threshold for all files
th = single(median(thresholds));
c = [th, median(cValues(:,2))];

%% Collect all mat files from datastore to create a single output
disp('Saving to Tiff ...');

if (isRunInDebugMode)
    fileExt = '.mat';
else
    fileExt = '.getmeout'; %Still a matfile but located slightly differently
end
ds = fileDatastore(awsModifyPathForCompetability(dirToSaveProcessedYFrames),'ReadFcn',@(x)(x),'FileExtensions',fileExt,'IncludeSubfolders',true); 
files = ds.Files;

%Make sure dir is empty
awsRmDir(tiffOutputFolder);

tt=tic;
ticBytes(gcp);
parfor yI=1:length(files)
    %Read
    slice = yOCTFromMat(files{yI});
    
    %Apply threshold
    slice(slice<th) = th;
    slice = log(slice);
    
    %Write
    tn = [tempname '.tif'];
    yOCT2Tif(slice,tn, log(c))
    awsCopyFile_MW1(tn, ...
        awsModifyPathForCompetability(sprintf('%s/y%04d.tif',tiffOutputFolder,yI))...
        ); %Matlab worker version of copy files
    delete(tn);
end
%Reorganize
awsCopyFile_MW2(tiffOutputFolder);

fprintf('Done saving as tif, toatl time: %.0f[min]\n',toc(tt)/60);
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
end