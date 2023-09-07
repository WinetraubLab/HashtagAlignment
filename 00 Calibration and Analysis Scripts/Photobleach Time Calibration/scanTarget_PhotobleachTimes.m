% In this scritp we will try to photobleach lines using several settings to
% see which one is optimal for line thickness

%% Inputs

% Exposure and n passes settings
exposures = [30 45 60 90 120 180]; % Units are sec per 1mm of line
nPasses =   [3  3  3  3   3   4]; % Number of passes should be as low as possible but still allow OCT scanner not to crash
% For 10x, we usually use: 15 sec/1mm and 2 passes.
% For 40x, we usually use: 5  sec/1mm and 2 passes.

% Photobleach pattern configuration
octProbePath = yOCTGetProbeIniPath('40x');
lineLength = 0.5; %mm

% z = 0 is the tissue/air interface.
zDepths = [-0.300, 0.000, 0.100]; %Photobleach line depth. mm. +z means deeper

% Set to true if you want to do a dry run
skipHardware = false;

%% Photobleach loop
for i=1:length(exposures)
    fprintf('%s Photobleaching line #%d. Exposure: %.1f sec/mm, nPasses: %d.\n', ...
        datestr(datetime),i,exposures(i),nPasses(i));
    
    % Perform photobleach
    yOCTPhotobleachTile([0;-lineLength/2],[0;+lineLength/2], ...
        'octProbePath',octProbePath, ...
        'exposure',exposures(i),'nPasses',nPasses(i),...
        'z',zDepths,'skipHardware',skipHardware,'plotPattern',true);
    
    pause(0.5);
    
    %Translate stage by a little
    if ~skipHardware
        [x0,y0,z0] = yOCTStageInit();
        yOCTStageMoveTo(x0+lineLength/4,y0,z0);
    end

    pause(0.5);
end