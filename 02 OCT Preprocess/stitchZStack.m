%This script stitches images aquired at different z depths 2gezer

%OCT Data
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01/OCT Volumes/';
reconstructConfig = {'dispersionParameterA',6.539e07}; %Configuration for processing OCT Volume

%Probe Data
focusSigma = 20; %Sigma size of focus [pixel]

%Save Some Intermediate Y Scans
saveYs = 3; %How many Bscans to save (for future reference)

%Low memory mode, save results to a Tiff remotely than gather them all at
%the very end
isMemSaveMode = true; 

%% Jenkins
if (isRunningOnJenkins() || exist('runninAll','var'))
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
thresholds = zeros(1,length(yIndexes));
imOutSize = [length(dim.z.values) length(dim.x.values) length(yIndexes)]; %z,x,y

%Memory Saving mode handeling
if isMemSaveMode
    if ~awsIsAWSPath(OCTVolumesFolder)
        tmpOutputPath = [OCTVolumesFolder '\tmpOutput\'];
        mkdir(tmpOutputPath);
        tmpOutputPathDs = tmpOutputPath; %Path for Datastore
    else
        awsSetCredentials(1); %We need CLI
        tmpOutputPath = awsModifyPathForCompetability([OCTVolumesFolder '/tmpOutput'],true);
        tmpOutputPathDs = awsModifyPathForCompetability(tmpOutputPath,false); %Path for Datastore
    end
    
    %In memory saving mode, if we already have some of the files for some
    %ys, no need to recalculate
    ds = fileDatastore(tmpOutputPathDs,'ReadFcn',@load,'FileExtensions','.tif');
    
    yIExists = zeros(size(ds.Files));
    for i=1:length(ds.Files)
        x = ds.Files{i};
        [~,fname] = fileparts(x);
        yIExists(i) = str2double(fname);
    end
    yIndexes(yIExists) = []; %Don't process same files twice.
    thresholds(yIExists) = []; %Don't process same files twice.
else
    imOut = zeros(imOutSize); %[z,x,y] 
end    

%Attach files to parallel pool
mypool=gcp;
addAttachedFiles(mypool,{'yOCT2Tif.m','awsCopyFileFolder.m'});

parfor yI=1:length(yIndexes) %Loop over y frames
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
        %factor(factor<exp(-1/2*3^2)) = 0; %Values too low / out of focus
          
        %Add to stack
        stack(:,:,zzI) = imtranslate((scan1.*factor),[0,zToScan(zzI)/pixSizeZ],'FillValues',NaN); 
            %In translation, compensate for water/tissue numerical
            %apperature
            
        %Save for overview Purpose
        if (sum(yIndexes(yI) == yToSave)>0)
            fprintf('Saving Slice to file, yI=%d, yIndex=%d, zVolume=%02d\n',yI,yIndexes(yI),zzI);
            yOCT2Tif(log(scan1),sprintf('%s/BScan_Y%03d.tif',fpTxt,yIndexes(yI)));
        end
    end
    
    if ~isMemSaveMode
        imOut(:,:,yI) = nanmean(stack,3);
    else
        %Memory saving mode
		try
			yOCT2Tif(nanmean(stack,3),sprintf('%s/%04d.tif',tmpOutputPath,yIndexes(yI)));
        catch
            fprintf('yI=%d,yIndex=%d, is yOCT2Tif.m exist? %d\n',yI,yIndexes(yI),exist('yOCT2Tif.m','file'));
            a = nanmean(stack,3); a=size(a);
            fprintf('yI=%d,yIndex=%d, size(nanmean(stack,3): [%d, %d]\n',yI,yIndexes(yI),a(1),a(1));
            fprintf('yI=%d,yIndex=%d, tmpOutputPath: %s\n',yI,yIndexes(yI),sprintf('%s/%04d.tif',tmpOutputPath,yIndexes(yI)));
            fprintf('yI=%d,yIndex=%d, running yOCT2Tif: [%d, %d]\n');

			yOCT2Tif(nanmean(stack,3),sprintf('%s/%04d.tif',tmpOutputPath,yIndexes(yI)));
		end
    end
    
    %Since we are dealing with a log scale, its important to trim the image
    %Let us trim the image using the signal at the gel (top of the image)
    tmp = nanmedian(squeeze(stack(:,:,1)),2);
    thresholds(yI) = max(tmp(:))/size(stack,3)/2; %Devided by the amount of averages
    
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

%% Load Individual tiffs and concatinate
if isMemSaveMode
    imOut = zeros(imOutSize,'single'); %z,x,y
    disp('Loading Data from individual files');
    for yI = 1:size(imOut,3)
        imOut(:,:,yI) = yOCTFromTif(sprintf('%s/%04d.tif',tmpOutputPath,yI));
    end
end

%% Average
th = mean(thresholds);
imOut1 = imOut;
imOut1(imOut1<th) = th;

%% Output Tiff
disp('Saving to Tiff ...');
yOCT2Tif(log(imOut1),[OCTVolumesFolder '/VolumeScanAbs.tif']);
disp('Done');

figure(1);
imagesc(squeeze(log(imOut1(:,:,round(size(imOut1,3)/2)))));
colormap bone;

%% Cleanup
if isMemSaveMode
    %Make a directory for all output files 
    if ~awsIsAWSPath(OCTVolumesFolder)
        rmdir(tmpOutputPath,'s');
    else
        [status,err] = system(['aws s3 rm ' tmpOutputPath ' --recursive']);
    end
end