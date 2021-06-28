% In this scritp we will try to photobleach lines using several settings to
% see which one is optimal for line thickness

%% Inputs

% Exposure and n passes settings
exposures = [1 2 5 10 15 30]; %Units are sec per 1mm of line
nPasses =   [2 2 2 2   2  3]; % Number of passes should be as low as possible but still allow OCT scanner not to crash
% For 10x, we usually use: 15 sec/1mm and 2 passes.
% For 40x, we usually use: 5  sec/1mm and 2 passes.

% Photobleach pattern configuration
octProbePath = getProbeIniPath('10x');

lineLength = 0.5; %mm
x = linspace(-lineLength/2,lineLength/2,length(exposures)+2); % X Positions of the lines
x([1 end]) = [];

%% Setup 
ThorlabsImagerNETLoadLib(); %Init library
ThorlabsImagerNET.ThorlabsImager.yOCTScannerInit(octProbePath); %Init OCT

%% Photobleach
yOCTTurnLaser(true);
for i=1:length(x)
    fprintf('%s Photobleaching line #%d. Exposure: %.1f sec/mm, nPasses: %d.\n', ...
        datestr(datetime),i,exposures(i)/lineLength,nPasses(i));
    ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
        x(i),-lineLength/2, ... Start X,Y
        x(i), lineLength/2, ... End X,y
        exposures(i),  ... Exposure time sec
        nPasses(i));
end
yOCTTurnLaser(false);

%% Clean up
ThorlabsImagerNET.ThorlabsImager.yOCTScannerClose();