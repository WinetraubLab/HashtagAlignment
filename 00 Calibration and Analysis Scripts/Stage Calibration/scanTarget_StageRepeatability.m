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
if ~isMockTrial
    fprintf('%s Pattern 1...\n',datestr(datetime));
    yOCTPhotobleachTile(pattern1_Start,pattern1_End,...
        'octProbePath',octProbePath,...
        'exposure',config.photobleach.exposure,...
        'nPasses',config.photobleach.nPasses ...
        ); 
    
    fprintf('%s Pattern 2...\n',datestr(datetime));
    yOCTPhotobleachTile(pattern1_Start,pattern1_End,...
        'octProbePath',octProbePath,...
        'exposure',config.photobleach.exposure,...
        'nPasses',config.photobleach.nPasses ...
        ); 
end

%% Plot
overallLines_Start = [pattern1_Start pattern2_Start];
overallLines_End = [pattern1_End pattern2_End];
figure(1);
for i=1:length(overallLines_Start)
    plot(...
        [overallLines_Start(1,i) overallLines_End(1,i)],...
        [overallLines_Start(2,i) overallLines_End(2,i)]);
    if (i==1)
        hold on;
    end
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