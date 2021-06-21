% In this scritp we will try to photobleach lines using several settings to
% see which one is optimal for line thickness

%% Inputs

exposures = [1 2 5 15 30 60]; %Units are sec per 1mm of line
nPasses =   [2 2 2 2  2  4 ]; % Number of passes should be as low as possible but still allow OCT scanner not to crash

x = linspace(-1,1,length(exposures)); % X Positions of the lines

% Photobleach pattern configuration
octProbePath = getProbeIniPath('40x');

%% Setup 
ThorlabsImagerNETLoadLib(); %Init library
ThorlabsImagerNET.ThorlabsImager.yOCTScannerInit(octProbePath); %Init OCT

%% Photobleach
yOCTTurnLaser(true);
for i=1:length(x)
    fprintf('%s Photobleaching line #%d. Exposure: %.1f sec, nPasses: %d.\n', ...
        datestr(datetime),i,exposures(i),nPasses(i));
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        x(i),x(i), ... Start X,Y
        -0.5,0.5 , ... End X,y
        exposures(i),  ... Exposure time sec
        nPasses(i));
end
yOCTTurnLaser(false);

%% Clean up
ThorlabsImagerNET.ThorlabsImager.yOCTScannerClose();