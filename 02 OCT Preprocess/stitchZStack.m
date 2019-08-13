%This script stitches images aquired at different z depths 2gezer

%OCT Data
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-001/OCT Volumes/';
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

%% Read Configuration file
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

pixSizeZ = diff(dim.z.values([1 2])); %um

%% Preform stitching
disp('Stitching ... '); tt=tic();

%Set up for paralel processing
yIndexes=dim.y.index;
thresholds = zeros(length(yIndexes),1);
cValues = zeros(length(yIndexes),2);
imOutSize = [length(dim.z.values) length(dim.x.values) length(yIndexes)]; %z,x,y
imToSave = cell(size(thresholds)); %For examples files

%Make sure a temporary folder to save the data is empty
tmpDir = [OCTVolumesFolder '/tmp/'];
awsRmDir(tmpDir);

%Setup parallel pool, attach everything we need
p=gcp('nocreate');
if ~isempty(p)
    %kill prev parpool before starting this one if it has SpmdEnabled flag
    if (p.SpmdEnabled)
        delete(p);
        p=parpool('SpmdEnabled',false);
    end
end
pds = fileDatastore('../','ReadFcn',@load,'FileExtensions','.m','IncludeSubfolders',true);  
addAttachedFiles(p,pds.Files);
%addAttachedFiles(p,{'tallWriter.m','yOCT2Mat.m','yOCTLoadInterfFromFile.m','yOCTInterfToScanCpx.m',})

%Loop over y frames
parfor (yI=1:length(yIndexes)) 
    try
    fprintf('%s Processing yIndex=%d (yI=%d of %d).\n',datestr(datetime),yIndexes(yI),yI,length(yIndexes)); %#ok<PFBNS>
    
    %Loop over depths
    stack = zeros([imOutSize(1:2), length(zToScan)])*NaN; %#ok<PFBNS> %z,x,zStach
    for zzI=1:length(zToScan)
        
        %Load Frame
        fpTxt = fp{zzI};
        [int1,dim1] = ...
            yOCTLoadInterfFromFile([{fpTxt}, reconstructConfig, {'YFramesToProcess',yIndexes(yI)}]);
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
    
    %Save Stack
    %Since we can't save directly to drive as AWS CLI, we will generate the
    %image and save it to a cell, upload later. This is a small dataset so
    %we can return it to matlab no need to use tall
    imToSave{yI} = [];
    if (sum(yIndexes(yI) == yToSave)>0)
        imToSave{yI} = single(stack);
    end
    
    %Compute stacked frame
    stackmean = squeeze(single(nanmean(stack,3))); 
    stack = []; %Clear memory
    
    %Save results to temporary files
    %Since this data is big, its better to upload it to destination than
    %return it to Matlab
    T = tall({stackmean});
    location = awsModifyPathForCompetability(sprintf('%s/y%04d/m*.mat',tmpDir,yIndexes(yI)),false);
    write(location,T,'WriteFcn',@tallWriter); %Not a trivial implementation but it works
    
    %Save thresholds, this data is small so we can send it back
    thresholds(yI) = th;
    cValues(yI,:) = c;
         
    catch ME
        fprintf('Error happened in parfor, iteration %d, yIndex: %d',yI,yIndexes(yI)); 
        for j=1:length(ME.stack) 
            ME.stack(j) 
        end 
        disp(ME.message); 
        error('Error in parfor');
    end
end
fprintf('Done stitching, toatl time: %.0f[min]\n',toc(tt)/60);

%% Threshlod
%Compute a single threshold for all files
th = single(mean(thresholds));

%% Collect all mat files from datastore to create a single output
disp('Saving to Tiff ...');

%Read (using parpool)
bv = yOCTReadBigVolume(tmpDir,'mat');

%Apply threshold
bv(bv<th) = th;
bv = log(bv);

%Write (using parpool)
location = awsModifyPathForCompetability([OCTVolumesFolder '/VolumeScanAbs/'],false);
yOCTWriteBigVolume(bv,dim, location,'tif',log(mean(cValues)));

%% Cleanup the temporary dir
awsRmDir(tmpDir); 

%% Save overviews of a few Y sections to log
logDir = [OCTVolumesFolder '02 OCT Preprocess Log'];
if ~awsIsAWSPath(logDir) && ~exist(logDir,'dir')
    mkdir(logDir);
end
for i=1:length(yToSave)
    if isempty(imToSave{yToSave(i)})
        fprintf('yI=%d is empty, was expecting to have an example volume to save\n',yToSave(i));
    else
        im = imToSave{yToSave(i)};
        im(im<th) = th;
        yOCT2Tif(log(im),sprintf('%s/y%03dZStack.tif',logDir,yToSave(i)),log(cValues(i,:)));
    end
end
