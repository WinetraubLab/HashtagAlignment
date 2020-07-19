% This script estimates OCT light depth of penetration.
% - Script for evaluating the depth of penetration in a given stitched volume. 
% - The script will generate figures of different slices for visualization and error detection.

%% Inputs

%OCT Data
OCTVolumesFolder = [s3SubjectPath('06','LC') 'OCTVolumes/'];
%OCTVolumesFolder = [s3SubjectPath('01') 'OCTVolumes/'];

%% Jenkins
if (exist('OCTVolumesFolder_','var'))
    OCTVolumesFolder = OCTVolumesFolder_;
end

%% Set folders
logPath = awsModifyPathForCompetability([OCTVolumesFolder '../Log/02 OCT Preprocess/DepthOfPenetration/']);

% Load scan config json for additional information
scanConfigPath = [OCTVolumesFolder '/ScanConfig.json'];
scanConfigJson = awsReadJSON(scanConfigPath);

%% Load Volume information
[~,meta] = yOCTFromTif([OCTVolumesFolder '/VolumeScanAbs/'],'isLoadMetadataOnly',true);  
zPixelSize_um = diff(meta.z.values(1:2))*1e3; % um/pix

% Select bScans to load, around the center of the scan as this is the
% relevant area.
bScanIndexs = meta.y.index(round(linspace(0,length(meta.y.index)-1,21)+0.5));
bScanIndexs([1 end]) = [];

% Change z coordinate system (if required) such that z=0 is the focus positoin of OCT image when zDepths=0 scan was taken.
if ~isfield(meta.z,'origin') || contains(meta.z.origin,'top of OCT image')
    meta.z.values = meta.z.values - ...
        (scanConfigJson.focusPositionInImageZpix-1)*zPixelSize_um*1e-3;
end

% Top of tissue in pixels
[~,zTopOfTissue_pix] = min(abs(meta.z.values-0));

%% Load Volumes and Compute depth of penetration
depthOfPenetrations = [];
tissueTopPositions = [];
surfaceIntensitys = [];
noiseIntensitys = [];
for BScanI=1:length(bScanIndexs)
    
    % Load a single B-Scan, saves time
    imOCT = yOCTFromTif([OCTVolumesFolder '/VolumeScanAbs/'],'yI',bScanIndexs(BScanI));
    
    %% Step #1 - find tissue surface
    
    % Keep data only around surface to prevent confusion
    imOCTTemp = imOCT;
    imOCTTemp(1:(zTopOfTissue_pix-200),:) = 0;
    imOCTTemp((zTopOfTissue_pix+350):end,:) = 0; 
    
    % Find bright spot and cluster
    BW = imbinarize(imOCTTemp,'adaptive','ForegroundPolarity','dark','Sensitivity',1);
    SE = strel('disk',2,8);
    BW = imdilate(imdilate(imdilate(imdilate(BW,SE),SE),SE),SE);
    CC = bwconncomp(BW);
    featuresSize = cellfun(@(x)(length(x)),CC.PixelIdxList);
    
    % Remove small clusters
    maxVal = max(featuresSize);
    for k=1:CC.NumObjects
        if length(CC.PixelIdxList{k})< maxVal/4
            BW(CC.PixelIdxList{k}) = 0;
        end
    end
    
    % For each x position, find surface z position
    [val, surfaceZPosition_px] = max(BW);
    surfaceZPosition_px(val ~= 1) = NaN; % x positions where no surface was found are nans
    
    % Interpolate where you couldn't find surface
    xI = 1:size(imOCT,2);
    nn = isnan(surfaceZPosition_px);
    surfaceZPosition_px = interp1(xI(~nn),surfaceZPosition_px(~nn),xI);
    surfaceZPosition_um = interp1(xI(~nn),meta.z.values(round(surfaceZPosition_px(~nn)))*1e3,xI);
    surfaceZPosition_um = surfaceZPosition_um(:)';
    
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
    
    %% Depth of penetration
    depthOfPenetration = maxDepthPosition_um(:)' - surfaceZPosition_um(:)';
    depthOfPenetration = depthOfPenetration(:)';
    
    %% Plot output
    figure(12);
    imagesc(meta.x.values*1e3,meta.z.values*1e3,imOCT); colormap gray
    title(sprintf('#%d OCT B-Scan, y=%.0f[\\mum]\nDepth of Penetration: %.0f[\\mum]',...
        BScanI, 1e3*meta.y.values(bScanIndexs(BScanI)),nanmedian(depthOfPenetration)));
    hold on;
    plot(meta.x.values*1e3,surfaceZPosition_um);
    plot(meta.x.values*1e3,maxDepthPosition_um);
    hold off;
    xlabel('x[\mum]');
    ylabel('z[\mum]');
    legend('Tissue Surface','Max Depth');
    grid on;
    awsSaveMatlabFigure(gcf,sprintf('%s/y%04d.png',logPath,bScanIndexs(BScanI)));
    
    %% Capture data
    depthOfPenetrations = [depthOfPenetrations depthOfPenetration(~isnan(depthOfPenetration))];
    tissueTopPositions = [tissueTopPositions surfaceZPosition_um(~isnan(surfaceZPosition_um))];
    surfaceIntensitys = [surfaceIntensitys surfaceIntensity];
    noiseIntensitys = [noiseIntensitys minIntensity];
end

%% Plot overall statistics
figure(12);
histogram(depthOfPenetrations,20);
grid on;
title (sprintf('Depth of Penetration at Different X-Y Positions\n Median: %.0f[\\mum]',...
    median(depthOfPenetrations)));
xlabel('Depth of Penetration [\mum]');
awsSaveMatlabFigure(gcf,[logPath 'DepthOfPenetrations.png']);

figure(12);
histogram(tissueTopPositions,20);
grid on;
title ('Tissue-Gel Interface Z at Different X-Y Positions');
xlabel(sprintf('Top of Tissue Z[\\mum]\nZ=0 is user selected focus position. Z>0 means deeper.'));
awsSaveMatlabFigure(gcf,[logPath 'TissueInterfacePositions.png']);

%% Save Statistics
scanConfigJson.volumeStatistics.depthOfPenetration_um = median(depthOfPenetrations);
scanConfigJson.volumeStatistics.minTissueInterfaceZ_um = prctile(tissueTopPositions,5);
scanConfigJson.volumeStatistics.maxTissueInterfaceZ_um = prctile(tissueTopPositions,95);
scanConfigJson.volumeStatistics.surfaceIntensity_db = median(surfaceIntensitys);
scanConfigJson.volumeStatistics.noiseFloor_db = median(noiseIntensitys);

scanConfigJson.volumeStatistics.notes = [ ...
    'depthOfPenetration_um - Median depth of penetration from tissue until loss of OCT signal.' newline ...
    'minTissueInterfaceZ_um and maxTissueInterfaceZ_um - Min/Max z position of gel-tissue interface. Z=0 is user selected focus position when scan started. Z>0 means deeper.' newline ...
    'surfaceIntensity_db - intensity at the surface of the tissue. Units: db.' newline ...
    'noiseFloor_db - intensity of the signal we consider to be the bare minimum to have detection. Units: dn.' newline ...
    ];

awsWriteJSON(scanConfigJson,scanConfigPath);