%This script stitches images aquired at different z depths 2gezer

%OCT Data
OCTVolumesFolder = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-00/OCT Volumes/';
reconstructConfig = {'dispersionParameterA',6.539e07}; %Configuration for processing OCT Volume

%Probe Data
focusSigma = 20; %Sigma size of focus [pixel]

%Save Some Intermediate Y Scans
saveYs = 3; %How many Bscans to save (for future reference)

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

%Get dimensions
dim = json.VolumeOCTDimensions;

%Save some Ys
yToSave = dim.y.index(...
    round(linspace(1,length(dim.y.index),saveYs)) ...
    );

%% Preform stitching
disp('Stitching ... '); tt=tic();
yIndexes=dim.y.index;
imOut = zeros([size(scan1) length(yIndexes)]); %[z,x,y]
for yI=yIndexes %Loop over y frames
    fprintf('%s Processing yI=%d of %d.\n',datestr(datetime),yI,length(yIndexes));
    
    %Loop over depths
    stack = zeros([size(imOut), length(zToScan)])*NaN;
    for zzI=1:length(zToScan)
        
        %Load Frame
        fpTxt = feval(fp,zzI);
        [int1,dim1] = ...
            yOCTLoadInterfFromFile([{fpTxt}, reconstructConfig, {'YFramesToProcess',yIndexes(yI)}]);
        [scan1,dim1] = yOCTInterfToScanCpx ([{int1 dim1} reconstructConfig]);
        scan1 = abs(scan1);
        for i=length(size(scan1)):-1:3 %Average BScan Averages, A Scan etc
            scan1 = squeeze(mean(scan1,i));
        end
        
        %Filter
        zI = 1:length(scan1); zI = zI(:);
        factor = repmat(exp(-(zI-focusPositionInImageZpix).^2/(2*focusSigma)^2), [1 size(scan1,2)]);
          
        %Add to stack
        stack(:,:,zzI) = imtranslate((scan1.*factor),[0,zToScan(zzI)/n],'FillValues',NaN); 
            %In translation, compensate for water/tissue numerical
            %apperature
            
        %Save for overview Purpose
        if (sum(yI == yToSave)>0)
            yOCT2Tif(log(scan1),sprintf('%s/BScan_Y%03d.tif',fp(zzI),yI));
        end
    end
    
    imOut(:,:,yI) = nanmean(stack,3);
end
fprintf('Done stitching, toatl time: %.0f[min]\n',toc(tt)/60);

%% Output Tiff
disp('Saving to Tiff ...');
yOCT2Tif(log(imOut),[OCTVolumesFolder '/VolumeScanAbs.tif']);
disp('Done');
