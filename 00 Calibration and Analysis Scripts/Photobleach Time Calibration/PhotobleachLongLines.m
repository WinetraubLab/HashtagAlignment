% In this scritp we will try to photobleach very long lines across the
% tissue

%% Inputs

% Exposure and n passes settings for each line
exposures = [90 120 180]; % Units are sec per 1mm of line
nPasses =   [ 3   3   4]; % Number of passes should be as low as possible but still allow OCT scanner not to crash

% Photobleach pattern configuration
octProbePath = yOCTGetProbeIniPath('40x');
lineLength = 4; % mm (centered around the first position)
lineSpacing = 0.5; % mm difference between two nearby lines

% z = 0 is the tissue/air interface.
zDepths = [-0.300, 0.000, 0.100]; %Photobleach line depth. mm. +z means deeper
% x displacement for each depth, set to 0 if you want z lines to be on top
% of each other or another value (less then lineSpacing) to have a "step"
% like photobleach
lineSpacingPerDepth = 0.1;% mm

% Set to true if you want to do a dry run
skipHardware = false;

%% Initiate lateral position
if ~skipHardware
    [x0,y0,z0] = yOCTStageInit();
end

%% Photobleach loop
for i=1:length(exposures) % Loop over x positions
    fprintf('%s Photobleaching line #%d. Exposure: %.1f sec/mm, nPasses: %d.\n', ...
        datestr(datetime),i,exposures(i),nPasses(i));
    
    % Loop over depths
    for j=1:length(zDepths)
        
        %Translate stage
        if ~skipHardware
            yOCTStageMoveTo(...
                x0 + (i-1)*lineSpacing + (j-1)*lineSpacingPerDepth,...
                y0,z0);
        end
        
        % Perform photobleach
        yOCTPhotobleachTile([0;-lineLength/2],[0;+lineLength/2], ...
            'octProbePath',octProbePath, ...
            'exposure',exposures(i),'nPasses',nPasses(i),...
            'z',zDepths(j),'skipHardware',skipHardware,'plotPattern',true);
        
        pause(0.5);
    end

    pause(0.5);
end

%% Clean up
if ~skipHardware
    yOCTStageMoveTo(x0,y0,z0); % Bring stage back to center
end