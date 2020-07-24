% This script estimates OCT light depth of penetration, tissue intefrace
% position and max depth for evry point in the volume.
% - Script for evaluating the depth of penetration in a given stitched volume. 
% - The script will generate figures of different slices for visualization and error detection.

%% Inputs

%OCT Data
OCTVolumesFolder = [s3SubjectPath('06','LC') 'OCTVolumes/'];
%OCTVolumesFolder = [s3SubjectPath('01') 'OCTVolumes/'];

isUploadToAWS = false; % Set to true if you would like to upload to aws

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
    isUploadToAWS = true;
end

%% Set folders
logPath = awsModifyPathForCompetability([OCTVolumesFolder '../Log/02 OCT Preprocess/DepthOfPenetration/']);
if isUploadToAWS && awsExist(logPath)
    awsRmDir(logPath); %Clear before upload
end

% Load scan config json for additional information
scanConfigPath = [OCTVolumesFolder '/ScanConfig.json'];
scanConfigJson = awsReadJSON(scanConfigPath);

%% Load Volume information
[~,meta] = yOCTFromTif([OCTVolumesFolder '/VolumeScanAbs/'],'isLoadMetadataOnly',true);  
zPixelSize_um = diff(meta.z.values(1:2))*1e3; % um/pix
xPixelSize_um = diff(meta.x.values(1:2))*1e3; % um/pix

% Select bScans to load, around the center of the scan as this is the
% relevant area.
bScanIndexs = meta.y.index(round(linspace(0,length(meta.y.index)-1,41)+0.5));
bScanIndexs([1 end]) = [];
bScanIndexs = [1;bScanIndexs;length(meta.y.index)];

% Change z coordinate system (if required) such that z=0 is the focus positoin of OCT image when zDepths=0 scan was taken.
if ~isfield(meta.z,'origin') || contains(meta.z.origin,'top of OCT image')
    meta.z.values = meta.z.values - ...
        (scanConfigJson.focusPositionInImageZpix-1)*zPixelSize_um*1e-3;
end

% Top of tissue in pixels
[~,zTopOfTissue_pix] = min(abs(meta.z.values-0));
zGelSurface = round(zTopOfTissue_pix + min((scanConfigJson.volume.zDepths*1000)/zPixelSize_um));
aboveFocusMask = min([100 (zTopOfTissue_pix-zGelSurface)-30]);

%% Load Volumes and Compute depth of penetration
depthOfPenetrations = [];
tissueTopPositions = [];
surfaceIntensitys = [];
noiseIntensitys = [];
tissueGelInterfaceZ_um = NaN*zeros(length(meta.y.values),length(meta.x.values));
maxLightPenetrationZ_um = tissueGelInterfaceZ_um;
for BScanI=1:length(bScanIndexs)
    
    % Load a single B-Scan, saves time
    imOCT = yOCTFromTif([OCTVolumesFolder '/VolumeScanAbs/'],'yI',bScanIndexs(BScanI));
    
    %% Step #1 - find tissue surface
    
    % Keep data only around surface to prevent confusion
    imOCTTemp = imOCT;
    imOCTTemp(1:(zTopOfTissue_pix-aboveFocusMask),:) = 0;
    imOCTTemp((zTopOfTissue_pix+350):end,:) = 0; 
    
    % Find bright spot and cluster
    BW = imbinarize(imOCTTemp,'adaptive','ForegroundPolarity','dark','Sensitivity',1);
    CC = bwconncomp(BW);
    featuresSize = cellfun(@(x)(length(x)),CC.PixelIdxList);
    featuresSize = sort(featuresSize,'descend');
    
    % Remove small clusters
    maxVal = max(featuresSize);
    %Val = featuresSize(ceil(length(featuresSize)*0.05));
    for k=1:CC.NumObjects
        if length(CC.PixelIdxList{k})<= maxVal/100
            BW(CC.PixelIdxList{k}) = 0;
        end
    end
    SE = strel('disk',2,8);
    BW = imdilate(imdilate(imdilate(imdilate(imdilate(BW,SE),SE),SE),SE),SE);
    
    
    % For each x position, find surface z position
    [val, surfaceZPosition_px] = max(BW);
    surfaceZPosition_px(val ~= 1) = NaN; % x positions where no surface was found are nans
    
    % Interpolate where you couldn't find surface
    xI = 1:size(imOCT,2);
    nn = isnan(surfaceZPosition_px);
    surfaceZPosition_px = interp1(xI(~nn),surfaceZPosition_px(~nn),xI);
    surfaceZPosition_um = interp1(xI(~nn),meta.z.values(round(surfaceZPosition_px(~nn)))*1e3,xI);
    surfaceZPosition_um = surfaceZPosition_um(:)';
    
    % Smooth, interface needs to be smooth to 10um level
    surfaceZPosition_um = mySmooth(surfaceZPosition_um, 10/xPixelSize_um);
    
    %% Step #2 - find deepest visible area (using SNR)
    
    % Make an average OCT signal.
    m = double(imOCT);
    %m(isnan(m)) = min(m(:));
    m = imgaussfilt(m,[5, 20]); %Filter less in z
    
    % Compute signal at the surface.
    surfaceIntensity = max(m,[],1); % Surface intensity as function of x
    surfaceIntensity = prctile(surfaceIntensity,70); % single value

    % Look at the lowest signal we find, min intensity should be x db above
    % that:
    minIntensity = min(mean(m,2))+6;
    
    % Figure out where SNR too low to see any data
    zI = repmat((1:size(m,1))',[1 size(m,2)]);
    mask = (m<minIntensity ... under minimal signal
        & zI >  repmat(surfaceZPosition_px(:)'+20,[size(m,1) 1]) ... below interface
        );
    
    % For each x position, find depth of penetration (in pixels)
    [val, maxDepthPosition_px] = max(mask);
    maxDepthPosition_um = meta.z.values(maxDepthPosition_px)*1e3;
    maxDepthPosition_px(val ~= 1) = NaN; % x positions where no bound was found are nans
    maxDepthPosition_um(val ~= 1) = NaN; % x positions where no bound was found are nans
    
    % Smooth, interface needs to be smooth to 10um level
    maxDepthPosition_um = imgaussfilt(maxDepthPosition_um, 10/xPixelSize_um);
    
    %% Depth of penetration
    depthOfPenetration = maxDepthPosition_um(:)' - surfaceZPosition_um(:)';
    depthOfPenetration = depthOfPenetration(:)';
    
    %% Plot output
    if mod(bScanIndexs(BScanI),100)==0
        figure(12);
        imagesc(meta.x.values*1e3,meta.z.values*1e3,imOCT); colormap gray
        title(sprintf('#%d OCT B-Scan, yI=%d\nDepth of Penetration: %.0f[\\mum]',...
            BScanI, bScanIndexs(BScanI), nanmedian(depthOfPenetration)));
        hold on;
        plot(meta.x.values*1e3,surfaceZPosition_um);
        plot(meta.x.values*1e3,maxDepthPosition_um);
        hold off;
        xlabel('x[\mum]');
        ylabel('z[\mum]');
        legend('Tissue Surface','Max Depth');
        grid on;
        
        if isUploadToAWS
            awsSaveMatlabFigure(gcf,sprintf('%s/y%04d.png',logPath,bScanIndexs(BScanI)));
        end
    end
    
    %% Capture data
    depthOfPenetrations = [depthOfPenetrations depthOfPenetration(~isnan(depthOfPenetration))];
    tissueTopPositions = [tissueTopPositions surfaceZPosition_um(~isnan(surfaceZPosition_um))];
    surfaceIntensitys = [surfaceIntensitys surfaceIntensity];
    noiseIntensitys = [noiseIntensitys minIntensity];
    
    tissueGelInterfaceZ_um(bScanIndexs(BScanI),:) = surfaceZPosition_um;
    maxLightPenetrationZ_um(bScanIndexs(BScanI),:) = maxDepthPosition_um;
end

%% Interpolate tissue interface positions
[yyi,xxi] = meshgrid(1:size(tissueGelInterfaceZ_um,1),1:size(tissueGelInterfaceZ_um,2));
tissueGelInterfaceZ_um = interp2(...
    yyi(bScanIndexs,:),xxi(bScanIndexs,:),tissueGelInterfaceZ_um(bScanIndexs,:),yyi,xxi,'spline');
maxLightPenetrationZ_um = interp2(...
    yyi(bScanIndexs,:),xxi(bScanIndexs,:),maxLightPenetrationZ_um(bScanIndexs,:),yyi,xxi,'spline');

% Save
if isUploadToAWS
    metaData = meta;
    metaData.z = [];
    metaData.z.units = 'um';
    metaData.z.meaning = 'for each pixel value is depth in microns. z=0 is where the focal position was at user selected scan start depth';
    scanConfigJson.volumeStatistics.tissueGelInterfaceImagePath = 'tissueGelInterfaceZ_um.tif';
    yOCT2Tif(tissueGelInterfaceZ_um,[OCTVolumesFolder '/TissueGelInterfaceZ_um.tif'],'metadata',metaData);
    scanConfigJson.volumeStatistics.depthOfPenetrationImagePath = 'maxLightPenetrationZ_um.tif';
    yOCT2Tif(maxLightPenetrationZ_um,[OCTVolumesFolder '/MaxLightPenetrationZ_um.tif'],'metadata',metaData);
end


%% Plot overall statistics
figure(12);
histogram(depthOfPenetrations,20);
grid on;
title (sprintf('Depth of Penetration at Different X-Y Positions\n Median: %.0f[\\mum]',...
    median(depthOfPenetrations)));
xlabel('Depth of Penetration [\mum]');
if isUploadToAWS
    awsSaveMatlabFigure(gcf,[logPath 'DepthOfPenetrations.png']);
end

figure(12);
histogram(tissueTopPositions,20);
grid on;
title ('Tissue-Gel Interface Z at Different X-Y Positions');
xlabel(sprintf('Top of Tissue Z[\\mum]\nZ=0 is user selected focus position. Z>0 means deeper.'));
if isUploadToAWS
    awsSaveMatlabFigure(gcf,[logPath 'TissueInterfacePositions.png']);
end

%% Save Statistics
scanConfigJson.volumeStatistics.depthOfPenetration_um = median(depthOfPenetrations);
scanConfigJson.volumeStatistics.minTissueInterfaceZ_um = prctile(tissueTopPositions,10);
scanConfigJson.volumeStatistics.maxTissueInterfaceZ_um = prctile(tissueTopPositions,90);
scanConfigJson.volumeStatistics.surfaceIntensity_db = median(surfaceIntensitys);
scanConfigJson.volumeStatistics.noiseFloor_db = median(noiseIntensitys);

scanConfigJson.volumeStatistics.notes = [ ...
    'depthOfPenetration_um - Median depth of penetration from tissue until loss of OCT signal.' newline ...
    'minTissueInterfaceZ_um and maxTissueInterfaceZ_um - Min/Max z position of gel-tissue interface. Z=0 is user selected focus position when scan started. Z>0 means deeper.' newline ...
    'surfaceIntensity_db - intensity at the surface of the tissue. Units: db.' newline ...
    'noiseFloor_db - intensity of the signal we consider to be the bare minimum to have detection. Units: dn.' newline ...
    ];

if isUploadToAWS
    awsWriteJSON(scanConfigJson,scanConfigPath);
end

function y = mySmooth(x, sigma)
y = imgaussfilt(x,sigma);
y(isnan(y)) = x(isnan(y));
end
