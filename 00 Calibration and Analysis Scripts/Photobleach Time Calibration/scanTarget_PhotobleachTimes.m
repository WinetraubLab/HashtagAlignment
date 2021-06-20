% In this scritp we will try to photobleach lines using several settings to
% see which one is optimal for line thickness

%% Inputs

exposures = [1 2 5 15 30 60]; %Units are sec per 1mm of line
nPasses = 2*ones(size(exposures)); % Number of passes should be as low as possible but still allow OCT scanner not to crash

x = linspace(-1,1,length(exposures)); % X Positions of the lines

%% Setup 

% Photobleach pattern configuration
octProbePath = getProbeIniPath();

ThorlabsImagerNETLoadLib(); %Init library
ThorlabsImagerNET.ThorlabsImager.yOCTScannerInit(octProbePath); %Init OCT

%% Photobleach
yOCTTurnLaser(true);
for i=1:length(x)
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        x(i),x(i), ... Start X,Y
        -0.5,0.5 , ... End X,y
        exposures(i),  ... Exposure time sec
        nPasses(i));
end
yOCTTurnLaser(false);