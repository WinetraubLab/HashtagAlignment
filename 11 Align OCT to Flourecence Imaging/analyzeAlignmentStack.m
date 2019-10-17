% This script loads all slides of one subject, compute trends
%run this script twice to correct slide alignment based on stack trned

%% Inputs
subjectFolder =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LC/LC-04/';

%If not empty, will write the overview files to Log Folder
logFolder = awsModifyPathForCompetability([subjectFolder '/Log/11 Align OCT to Flourecence Imaging/']);
%logFolder = [];

%% Find all JSONS
awsSetCredentials(1);

disp([datestr(now) ' Loading JSONs']);
ds = fileDatastore(awsModifyPathForCompetability(subjectFolder),'ReadFcn',@awsReadJSON,'FileExtensions','.json','IncludeSubfolders',true);
jsons = ds.readall();

octJsonI = [find(cellfun(@(x)contains(x,'/ScanConfig.json'),ds.Files)); find(cellfun(@(x)contains(x,'\ScanConfig.json'),ds.Files))];
octVolumeJsonFilePath = ds.Files{octJsonI};
octVolumeJson = jsons{octJsonI};

slideJsonsI = find(cellfun(@(x)contains(x,'SlideConfig.json'),ds.Files));
slideJsonFilePaths = ds.Files(slideJsonsI);
slideJsons = [jsons{slideJsonsI}];

%% Load Enface view if avilable 
try
    ds = fileDatastore([subjectFolder '/OCTVolumes/OverviewScanAbs_Enface.tif'],'ReadFcn',@yOCTFromTif,'FileExtensions','.tif','IncludeSubfolders',true);
    enfaceView = ds.read();
catch
    enfaceView = [];
end

%%  Figure out slide names & other parameters
slideNames = cell(size(slideJsonFilePaths));
singlePlanes = slideNames;
fs = slideNames;
for i=1:length(slideNames)
    [~, sn] = fileparts([fileparts(slideJsonFilePaths{i}) '.tmp']);
    slideNames{i} = sn;
    
    if isfield(slideJsons(i).FM,'singlePlaneFit')
        singlePlanes{i} = slideJsons(i).FM.singlePlaneFit;
    end
    if isfield(slideJsons(i).FM,'fiducialLines')
        fs{i} = slideJsons(i).FM.fiducialLines;
    end
end

%Non empty options
ii = find(~cellfun(@isempty,singlePlanes) & ~cellfun(@isempty,fs));
singlePlanes = singlePlanes(ii);
singlePlanes = [singlePlanes{:}];
slideNames = slideNames(ii);
fs = fs(ii);

%% For every fame compute key parameters
plans_x = zeros(2,length(ii)); %(Start & Finish, n)
plans_y = plans_x; 
if (isfield(octVolumeJson.photobleach,'lineLength'))
    l = octVolumeJson.photobleach.lineLength;
else
    l = 2;%mm
end

for i=1:length(ii)
    
    %Extract data
    sp = singlePlanes(i);
    f = fs{i};
    
    c = mean([sp.xIntercept_mm sp.yIntercept_mm],2);
    slopeV = [1; sp.m];
    slopeV = slopeV/norm(slopeV);
    
    plans_x(:,i) = c(1)+slopeV(1)*l/2*[1 -1];
    plans_y(:,i) = c(2)+slopeV(2)*l/2*[1 -1];
end

d_mm = zeros(1,length(ii));%Directional distance
slideCenter_mm = zeros(2,length(ii)); %Center position of the slide (x/y,n)

%Compute prepandicular direction to the slides
sn = ii(:)';
xm = mean(plans_x,1);
ym = mean(plans_y,1);
px = polyfit(sn,xm,1);
py = polyfit(sn,ym,1);
n = [px(1);py(1)]; n = n/norm(n);

for i=1:length(ii)
    
    %Extract data
    sp = singlePlanes(i);
    
    c = mean([sp.xIntercept_mm sp.yIntercept_mm],2); 
    slideCenter_mm(:,i) = c;
    d_mm(i) = sign(dot(c,n))*norm(c);
end

figure(100);
subplot(1,1,1); %Clear previuse figure
%% Plot all planes on one figure
subplot(2,2,1);

%Plot Photobleached lines
if isfield(octVolumeJson,'version') && octVolumeJson.version == 2
    vLinePositions = octVolumeJson.photobleach.vLinePositions;
    hLinePositions = octVolumeJson.photobleach.hLinePositions;
    lineLength = octVolumeJson.photobleach.lineLength;
else
    vLinePositions = octVolumeJson.vLinePositions;
    hLinePositions = octVolumeJson.hLinePositions;
    lineLength = octVolumeJson.lineLength;
end

spfPlotTopView( ...
    singlePlanes,hLinePositions,vLinePositions, ...
    'lineLength',lineLength,'planeNames',slideNames, ...
    'theDot',[octVolumeJson.theDotX; octVolumeJson.theDotY] ...
    );

%% Plot distance to origin
subplot(2,2,3);

%Fit distance to origin, in the fit remove unusual jumps
d = abs(diff(d_mm)); md = median(d);
isOutlyer = [d>md*3 false]; %Unusual are distances which are much bigger than expected
p = polyfit(sn(~isOutlyer),d_mm(~isOutlyer),1);

%Plot
plot(sn,polyval(p,sn),'--r',mean(sn),polyval(p,mean(sn)),'.r');
y = ylim;
hold on;
plot(sn,d_mm,'.');
hold off;
ylim(y);
ylabel('\mum');
xlabel('Slide #')
title('Distance From Origin');
grid on;
legend(...
    sprintf('%.0f\\mum/slide \\pm%.0f\\mum',...
    abs(p(1))*1000,...
    std(polyval(p,sn(~isOutlyer))-d_mm(~isOutlyer))/sqrt(sum(~isOutlyer))*1000 ...
    ),...
    sprintf('Center: %.0f\\mum',polyval(p,mean(sn))*1000), ...
    'location','north');

%% Plot rotations
subplot(2,2,2);
rot = [singlePlanes.rotation_deg];
plot(sn,rot,'.')
hold on;
plot(sn([1 end]),median(rot)*[1 1],'--');
hold off;
ylabel('deg');
xlabel('Slide #');
title(sprintf('Rotation Angle: %.1f \\pm %.1f[deg]',mean(rot),std(rot)));
grid on;

%% Plot size change 
subplot(2,2,4);
sc = [singlePlanes.sizeChange_precent];
plot(sn,sc,'.')
hold on;
plot(sn([1 end]),median(sc)*[1 1],'--');
hold off;
ylabel('%');
xlabel('Slide #');
title(sprintf('1D Pixel Size Change: %.1f \\pm %.1f [%%]',mean(sc),std(sc)));
grid on;

%% Save to log
if ~isempty(logFolder)
    saveas(gcf,'StackAlignmentFigure1.png');
    awsCopyFileFolder('StackAlignmentFigure1.png',[logFolder '/StackAlignmentFigure1.png']);
end

%% Plot top view in a new figure with enface under it
figure(42);
spfPlotTopView( ...
    singlePlanes,hLinePositions,vLinePositions, ...
    'lineLength',lineLength,'planeNames',slideNames, ...
    'theDot',[octVolumeJson.theDotX; octVolumeJson.theDotY],...
    'enfaceViewImage',enfaceView, ...
    'enfaceViewImageXLim', [min(octVolumeJson.overview.xCenters) max(octVolumeJson.overview.xCenters)] + octVolumeJson.overview.range*[-1/2 1/2],...
    'enfaceViewImageYLim', [min(octVolumeJson.overview.yCenters) max(octVolumeJson.overview.yCenters)] + octVolumeJson.overview.range*[-1/2 1/2] ...
    );

%% Save to log
if ~isempty(logFolder)
    saveas(gcf,'StackAlignmentFigure2.png');
    awsCopyFileFolder('StackAlignmentFigure2.png',[logFolder '/StackAlignmentFigure2.png']);
end