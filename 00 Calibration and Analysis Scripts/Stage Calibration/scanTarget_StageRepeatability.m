% This script will draw a target to measure repetablilty of photobleach

%% Inputs
% skipHardware: When set to true the stage will not move and we will not
% photobleach. Use "true" when you would like to see the output without
% physcaily running the test.
skipHardware = true;  % If true, skip real photobleaching and scanning

% Photobleach pattern configuration
lens = '40x';
scanner = 'OCTP900';
octProbePath = yOCTGetProbeIniPath(lens, scanner);

% Current calibration angle between OCT and Stage
oct2stageXYAngleDeg = 0;

% Hashtag Photobleach Configurations
exposure_mm_sec = 2; % mm/sec
nPasses = 4; % Keep as low as possible. If galvo gets stuck, increase number

%% Define pattern template
switch(lens)
    case '10x'
        L = 3;% Positions to move around (mm)
        L1 = 0.5; %(mm)
        L2 = 0.6; %(mm)
    case '40x'
        L = 2.5; % Positions to move around (mm)
        L1 = 0.3; %(mm)
        L2 = 0.4; %(mm)
end

% Square shape
template1_Start = [ ...
    -L1  L1 L1 -L1;...
    -L1 -L1 L1  L1;...
    ];
template1_End = template1_Start(:,[2 3 4 1]);

% Add L Shape
template1_Start = [template1_Start [-L2 -L2;  L2 -L2]];
template1_End =   [template1_End   [-L2  0; -L2 -L2]];

% Cross
template2_Start = [ ...
     0  -L2 ;...
    -L2  0  ;...
    ];
template2_End = -template2_Start;

%% Define pattern
makePattern = @(p)(...
    [p (p(:,1:min(end,4))+[L;0]) (p(:,1:min(end,4))+[-L;0]) (p(:,1:min(end,4))+[0;L]) (p(:,1:min(end,4))+[0;-L])] ...
    );

pattern1_Start = makePattern(template1_Start);
pattern1_End = makePattern(template1_End);
pattern2_Start = makePattern(template2_Start);
pattern2_End = makePattern(template2_End);

%% Photobleach the two patterns
fprintf('%s Pattern 1, draw squares...\n',datestr(datetime));
json1 = yOCTPhotobleachTile(pattern1_Start,pattern1_End,...
    'octProbePath',octProbePath,...
    'exposure',exposure_mm_sec,...
    'nPasses',nPasses,...
    'skipHardware',skipHardware, ...
    'oct2stageXYAngleDeg',oct2stageXYAngleDeg, ...
    'plotPattern',true,...
    'v',true);

fprintf('%s Pattern 2, drow a cross in the middle of FOV for every position...\n',datestr(datetime));
if ~skipHardware
    ThorlabsImagerNETLoadLib(); %Init library
    ThorlabsImagerNET.ThorlabsImager.yOCTScannerInit(octProbePath); % Init OCT System
    [x0,y0,z0] = yOCTStageInit(oct2stageXYAngleDeg, NaN, NaN, v);   % Initialize Translation Stage
    ini = yOCTReadProbeIniToStruct(octProbePath);                   % Load probe ini

    yOCTTurnOpticalSwitch('init'); % Initialize first
	yOCTTurnOpticalSwitch('OCT');  % Set switch position away from photodiode
    yOCTTurnLaser(true);           % Turn beam on
end

xcc = [0 L -L 0  0];
ycc = [0 0 0  L -L];

for i=1:length(xcc)
    
    % Put pattern at the center of FOV
    if ~skipHardware
        yOCTStageMoveTo(x0+xcc(i),y0+ycc(i),NaN,true);
    
        % Photobleach Pattern
        for j=1:length(template2_Start)
            d = sqrt(sum( (template2_Start(:,j) - template2_End(:,j)).^2));
            
            % Turn optical switch on
            yOCTTurnOpticalSwitch('photodiode');
            
            % Pattern line
            ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
                template2_Start(1,j),template2_Start(2,j), ... Start X,Y
                template2_End(1,j),  template2_End(2,j)  , ... End X,y
                exposure_mm_sec*d,  ... Exposure time sec
                nPasses);
            
            % Set optical switch to "off" position
            yOCTTurnOpticalSwitch('OCT');

            % Wait before moving the stage to next position to prevent stage
            % motor jamming.
            pause(0.5);
        end
    end
end
% Clean up
if ~skipHardware
    yOCTTurnOpticalSwitch('OCT');       % Set switch position away from photodiode
    yOCTTurnLaser(false);               % Turn off the beam
    yOCTStageMoveTo(x0,y0,NaN,true);    % Return stage to original position
    ThorlabsImagerNET.ThorlabsImager.yOCTScannerClose(); % Clean up
end

%% Plot
isPlot2ndPattern = true;

overallLines_Start = [pattern1_Start pattern2_Start];
overallLines_End = [pattern1_End pattern2_End];
figure(1);
% Plot the photobleached lines
for i=1:length(pattern1_Start)
    plot(...
        [pattern1_Start(1,i) pattern1_End(1,i)],...
        [pattern1_Start(2,i) pattern1_End(2,i)]);
    if (i==1)
        hold on;
    end
end
if isPlot2ndPattern
    for i=1:length(pattern2_Start)
        plot(...
            [pattern2_Start(1,i) pattern2_End(1,i)],...
            [pattern2_Start(2,i) pattern2_End(2,i)],'k','LineWidth',2);
    end
end

% Plot the stage center positions
for i=1:length(json1.photobleachPlan)
    x = json1.photobleachPlan(i).stageCenterX_mm;
    y = json1.photobleachPlan(i).stageCenterY_mm;
    plot(x,y,'ob');
    text(x,y,sprintf('Stage %d',i),'HorizontalAlignment','center','VerticalAlignment','top');
end
hold off;
axis equal;
ylim([...
    round(min([overallLines_Start(2,:) overallLines_End(2,:)])-0.5)
    round(max([overallLines_Start(2,:) overallLines_End(2,:)])+0.5) ...
    ]);
xlabel('x[mm]');
ylabel('y[mm]');
title('Photobleach Pattern');
grid on;
