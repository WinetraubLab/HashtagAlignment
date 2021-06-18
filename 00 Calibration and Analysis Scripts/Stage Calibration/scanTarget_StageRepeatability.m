% This script will draw a target to measure repetablilty of photobleach

%% Inputs
% Mock option: When set to true the stage will not move and we will not
% photobleach. Use "true" when you would like to see the output without
% physcaily running the test.
isMockTrial = false;

% Photobleach pattern configuration
octProbePath = getProbeIniPath();

%% Reference Scan JSON - where to get default scan parameters from
subjectPaths = s3GetAllSubjectsInLib();
subjectPath = subjectPaths{end};
config = awsReadJSON([subjectPath 'OCTVolumes/ScanConfig.json']);

%% Define pattern template
L = 3; % Positions to move around (mm)
L1 = 0.4; %(mm)
L2 = L1*1.5; %(mm)

template1_Start = [ ...
    -L1  L1 L1 -L1;...
    -L1 -L1 L1  L1;...
    ];
template1_End = template1_Start(:,[2 3 4 1]);

% Add L Shape
template1_Start = [template1_Start [-L2 -L2;  L2 -L2]];
template1_End =   [template1_End   [-L2  L2; -L2 -L2]];

template2_Start = [ ...
     0  -L2 ;...
    -L2  0  ;...
    ];
template2_End = -template2_Start;

%% Define pattern
makePattern = @(p)(...
    [p (p+[L;0]) (p+[-L;0]) (p+[0;L]) (p+[0;-L])] ...
    );

pattern1_Start = makePattern(template1_Start);
pattern1_End = makePattern(template1_End);
pattern2_Start = makePattern(template2_Start);
pattern2_End = makePattern(template2_End);

%% Photobleach the two patterns
fprintf('%s Pattern 1...\n',datestr(datetime));
json1 = yOCTPhotobleachTile(pattern1_Start,pattern1_End,...
    'octProbePath',octProbePath,...
    'exposure',config.photobleach.exposure,...
    'nPasses',config.photobleach.nPasses,...
    'skipHardware',isMockTrial ...
    ); 

fprintf('%s Pattern 2...\n',datestr(datetime));
json2 = yOCTPhotobleachTile(pattern2_Start,pattern2_End,...
    'octProbePath',octProbePath,...
    'exposure',config.photobleach.exposure,...
    'nPasses',config.photobleach.nPasses,...
    'skipHardware',isMockTrial ...
    ); 

%% Plot
overallLines_Start = [pattern1_Start pattern2_Start];
overallLines_End = [pattern1_End pattern2_End];
figure(1);
% Plot the photobleached lines
for i=1:length(overallLines_Start)
    plot(...
        [overallLines_Start(1,i) overallLines_End(1,i)],...
        [overallLines_Start(2,i) overallLines_End(2,i)]);
    if (i==1)
        hold on;
    end
end

if (length([json1.photobleachInstructions.stageCenterX]) ~= length([json2.photobleachInstructions.stageCenterX]) || ...
    any([json1.photobleachInstructions.stageCenterX]~=[json2.photobleachInstructions.stageCenterX])) 
    warning('Cant trust stage position markers');
end
% Plot the stage center positions
for i=1:length(json1.photobleachInstructions)
    x = json1.photobleachInstructions(i).stageCenterX;
    y = json1.photobleachInstructions(i).stageCenterY;
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