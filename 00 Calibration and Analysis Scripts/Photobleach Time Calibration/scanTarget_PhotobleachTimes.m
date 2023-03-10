% In this scritp we will try to photobleach lines using several settings to
% see which one is optimal for line thickness

%% Inputs

% Exposure and n passes settings
exposures = [1 2 5 10 15 30 45 60]; % Units are sec per 1mm of line
nPasses =   [2 2 2 2   2  3  3  3]; % Number of passes should be as low as possible but still allow OCT scanner not to crash
% For 10x, we usually use: 15 sec/1mm and 2 passes.
% For 40x, we usually use: 5  sec/1mm and 2 passes.

% Photobleach pattern configuration
octProbePath = getProbeIniPath('40x');
lineLength = 0.5; %mm

zDepths = [0, 0.1, 0.2]; %Photobleach line depth. mm. +z means deeper

%% Photobleach loop
for i=1:length(x)
    fprintf('%s Photobleaching line #%d. Exposure: %.1f sec/mm, nPasses: %d.\n', ...
        datestr(datetime),i,exposures(i),nPasses(i));
    
    % Perform photobleach
    yOCTPhotobleachTile([0,-lineLength/2],[0,+lineLength/2], ...
        'octProbePath',octProbePath, ...
        'exposure',exposures(i),'nPasses',nPasses(i),...
        'z',zDepths);
    
    pause(0.5);
    
    %Translate stage by a little
    [x0,y0,z0] = yOCTStageInit();
    yOCTStageMoveTo(x0+lineLength/4,y0,z0);

    pause(0.5);
end