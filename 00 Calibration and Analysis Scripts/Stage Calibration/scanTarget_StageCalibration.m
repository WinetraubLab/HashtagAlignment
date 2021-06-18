% In order to calibrate stage units to phisical units we photobleach a
% pattern onto a gel then scan the pattern and compare

%% Inputs

nJumps = 10; % Number of calibration markers
motorMovement = 0.5; % mm
d = 0.1; % mm. Movement within lens FOV

% Photobleach pattern configuration
octProbePath = getProbeIniPath();

% Reference Scan JSON - where to get default scan parameters from
subjectPaths = s3GetAllSubjectsInLib();
subjectPath = subjectPaths{end};
config = awsReadJSON([subjectPath 'OCTVolumes/ScanConfig.json']);

% Mock option: When set to true the stage will not move and we will not
% photobleach. Use "true" when you would like to see the output without
% physcaily running the test.
isMockTrial = false;

%% Create a photobleach template, one for x galvo and the other for y galvo
L = config.photobleach.lineLength/2;

xGalvoTemplate_Start = [ ...
     0,  d, ;...
    -L, -3/4*L, ;...
    ];
xGalvoTemplate_End = [ ...
     0, d, ;...
     L, 3/4*L, ;...
    ];

yGalvoTemplate_Start = [ ...
    -L, -L, 1/4*L, ;...
     0,  d, d, ;...
    ];
yGalvoTemplate_End = [ ...
     L, -1/4*L, L, ;...
     0,  d,     d, ;...
    ];

%% Initialization
overallLines_Start = [];
overallLines_End = [];

if ~isMockTrial
    
    fprintf('%s Initialzing... \n\t(if Matlab is taking more than 2 minutes to finish this step, restart matlab and try again)\n',datestr(datetime));
    
    ThorlabsImagerNETLoadLib(); %Init library
    [x0,y0] = yOCTStageInit();
    
    fprintf('%s Initialzing Completed.\n',datestr(datetime));
end

%% X
fprintf('%s X Stage Lines...\n',datestr(datetime));
for i=1:nJumps
    dx = motorMovement*(i-1);
    
    if ~isMockTrial 
        fprintf('%s Line set %d of %d.\n',datestr(datetime),i,nJumps);
        yOCTStageMoveTo(x0+dx);
        
        yOCTPhotobleachTile(xGalvoTemplate_Start,xGalvoTemplate_End,...
            'octProbePath',octProbePath,...
            'exposure',config.photobleach.exposure,...
            'nPasses',config.photobleach.nPasses, ...
            'v', false); 
    end
    
    tmp_start = xGalvoTemplate_Start; tmp_start(1,:) = tmp_start(1,:)+dx;
    tmp_end   = xGalvoTemplate_End;   tmp_end(1,:)   = tmp_end(1,:)+dx;
    
    overallLines_Start = [overallLines_Start tmp_start];
    overallLines_End = [overallLines_End tmp_end];
end

%Return stage to original position
if ~isMockTrial
    yOCTStageMoveTo(x0,y0);
end

%% Y
fprintf('%s Y Stage Lines...\n',datestr(datetime));
for i=1:nJumps
    dy = motorMovement*(i-1)+L*2;
    
    if ~isMockTrial
        fprintf('%s Line set %d of %d.\n',datestr(datetime),i,nJumps);
        yOCTStageMoveTo(NaN,y0+dy);
        
        yOCTPhotobleachTile(yGalvoTemplate_Start,yGalvoTemplate_End,...
            'octProbePath',octProbePath,...
            'exposure',config.photobleach.exposure,...
            'nPasses',config.photobleach.nPasses, ...
            'v', false); 
    end
    
    tmp_start = yGalvoTemplate_Start; tmp_start(2,:) = tmp_start(2,:)+dy;
    tmp_end   = yGalvoTemplate_End;   tmp_end(2,:) = tmp_end(2,:)+dy;
    
    overallLines_Start = [overallLines_Start tmp_start];
    overallLines_End = [overallLines_End tmp_end];
end

%Return stage to original position
if ~isMockTrial
    yOCTStageMoveTo(x0,y0);
end

%% Plot
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