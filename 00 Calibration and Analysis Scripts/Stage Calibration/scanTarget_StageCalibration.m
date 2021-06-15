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

isDoMove = false; % Would you like the stage to actually move or just pretend for testing?

%% Create a photobleach template, one for x galvo and the other for y galvo
L = config.photobleach.lineLength/2;
l = L/2;


xGalvoTemplate_Start = [ ...
     0,  d, ;...
    -L, -L, ;...
    ];
xGalvoTemplate_End = [ ...
     0, d, ;...
     L, L, ;...
    ];

yGalvoTemplate_Start = [ ...
    -L, -L, l, ;...
     0,  d, d, ;...
    ];
yGalvoTemplate_End = [ ...
     L, -l, L, ;...
     0,  d, d, ;...
    ];

%% Initialization
overallLines_Start = [];
overallLines_End = [];

if isDoMove
    ThorlabsImagerNETLoadLib(); %Init library
    
    x0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('x'); %Init stage
    y0=ThorlabsImagerNET.ThorlabsImager.yOCTStageInit('y'); %Init stage
end

%% X
for i=1:nJumps
    dx = motorMovement*(i-1);
    
    if isDoMove
        ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('x',x0+dx); %Movement [mm]
        yOCTPhotobleachTile(xGalvoTemplate_Start,xGalvoTemplate_End,...
            'octProbePath',octProbePath,...
            'exposure',config.photobleach.exposure,...
            'nPasses',config.photobleach.nPasses); 
    end
    
    tmp_start = xGalvoTemplate_Start; tmp_start(1,:) = tmp_start(1,:)+dx;
    tmp_end   = xGalvoTemplate_End;   tmp_end(1,:)   = tmp_end(1,:)+dx;
    
    overallLines_Start = [overallLines_Start tmp_start];
    overallLines_End = [overallLines_End tmp_end];
end

%Return stage to original position
if isDoMove
    ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('x',x0);
    ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('y',y0);
end

%% Y
for i=1:nJumps
    dy = motorMovement*(i-1)+L*2;
    
    if isDoMove
        ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('y',y0+dy); %Movement [mm]
        yOCTPhotobleachTile(yGalvoTemplate_Start,yGalvoTemplate_End,...
            'octProbePath',octProbePath,...
            'exposure',config.photobleach.exposure,...
            'nPasses',config.photobleach.nPasses); 
    end
    
    tmp_start = yGalvoTemplate_Start; tmp_start(2,:) = tmp_start(2,:)+dy;
    tmp_end   = yGalvoTemplate_End;   tmp_end(2,:) = tmp_end(2,:)+dy;
    
    overallLines_Start = [overallLines_Start tmp_start];
    overallLines_End = [overallLines_End tmp_end];
end

%Return stage to original position
if isDoMove
    ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('x',x0);
    ThorlabsImagerNET.ThorlabsImager.yOCTStageSetPosition('y',y0);
end


%% Drow
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