% This script loads all slides of one subject, compute trends
%run this script twice to correct slide alignment based on stack trned

%% Inputs
subjectFolder = s3SubjectPath('01');
if exist('subjectFolder_','var')
    subjectFolder = subjectFolder_; %JSON
end

%If not empty, will write the overview files to Log Folder
logFolder = awsModifyPathForCompetability([subjectFolder '/Log/11 Align OCT to Flourecence Imaging/']);
%logFolder = [];

isRotOkThreshold = 5; %[deg], allowed variance around median to account rotation angle as ok
isSCOkThreshold  = 6; %[%], allowed variance around median to accoutn size change (in precent) as ok

%% Find all JSONS
awsSetCredentials(1);

[~,subjectName] = fileparts([subjectFolder(1:end-1) '.a']);

disp([datestr(now) ' Loading JSONs']);
ds = fileDatastore(awsModifyPathForCompetability(subjectFolder),'ReadFcn',@awsReadJSON,'FileExtensions','.json','IncludeSubfolders',true);
jsons = ds.readall();

%OCT
octJsonI = [find(cellfun(@(x)contains(x,'/ScanConfig.json'),ds.Files)); find(cellfun(@(x)contains(x,'\ScanConfig.json'),ds.Files))];
octVolumeJsonFilePath = ds.Files{octJsonI};
octVolumeJson = jsons{octJsonI};

%Sections
sectionJsonsI = find(cellfun(@(x)contains(x,'SlideConfig.json'),ds.Files));
sectionJsonFilePaths = ds.Files(sectionJsonsI);
sectionJsons = {jsons{sectionJsonsI}};

%Histology Instructions
hiJsonI = find(cellfun(@(x)contains(x,'HistologyInstructions.json'),ds.Files));
hiJsonFilePath = ds.Files{hiJsonI(1)};
hiJson = jsons{hiJsonI};

%% Load Enface view if avilable 
try
    ds = fileDatastore([subjectFolder '/OCTVolumes/OverviewScanAbs_Enface.tif'],'ReadFcn',@yOCTFromTif,'FileExtensions','.tif','IncludeSubfolders',true);
    enfaceView = ds.read();
catch
    enfaceView = [];
end

%%  Figure out slide names & other parameters
sectionNames = cell(size(sectionJsonFilePaths));
sectionIndexInStack = zeros(size(sectionJsonFilePaths));
singlePlanes = cell(size(sectionJsonFilePaths)); %Single plane fits
fs = sectionNames;
for i=1:length(sectionNames)
    [~, sn] = fileparts([fileparts(sectionJsonFilePaths{i}) '.tmp']);
    sectionNames{i} = sn;
    
    if isfield(sectionJsons{i}.FM,'singlePlaneFit')
        singlePlanes{i} = sectionJsons{i}.FM.singlePlaneFit;
    end
    if isfield(sectionJsons{i}.FM,'fiducialLines')
        fs{i} = sectionJsons{i}.FM.fiducialLines;
    end
    
    sectionIndexInStack(i) = find(cellfun(@(x)(contains(x,sn)),hiJson.sectionName)==1,1,'first');
end

%Non empty options
ii = find(~cellfun(@isempty,singlePlanes) & ~cellfun(@isempty,fs));
singlePlanes = singlePlanes(ii);
singlePlanes = [singlePlanes{:}];
sectionNames = sectionNames(ii);
sectionIndexInStack = sectionIndexInStack(ii);
sectionIndexInStack = sectionIndexInStack(:)';
fs = fs(ii);

%% For every section compute key parameters
plans_x = zeros(2,length(ii)); %(Start & Finish, n)
plans_y = plans_x; 
if isfield(octVolumeJson,'version') && octVolumeJson.version == 2
    vLinePositions = octVolumeJson.photobleach.vLinePositions;
    hLinePositions = octVolumeJson.photobleach.hLinePositions;
    lineLength = octVolumeJson.photobleach.lineLength;
else
    vLinePositions = octVolumeJson.vLinePositions;
    hLinePositions = octVolumeJson.hLinePositions;
    lineLength = octVolumeJson.lineLength;
end

for i=1:length(ii)
    
    %Extract data
    sp = singlePlanes(i);
    f = fs{i};
    
    c = mean([sp.xIntercept_mm sp.yIntercept_mm],2);
    slopeV = [1; sp.m];
    slopeV = slopeV/norm(slopeV);
    
    plans_x(:,i) = c(1)+slopeV(1)*lineLength/2*[1 -1];
    plans_y(:,i) = c(2)+slopeV(2)*lineLength/2*[1 -1];
end

d_mm = zeros(1,length(ii));%Directional distance
slideCenter_mm = zeros(2,length(ii)); %Center position of the slide (x/y,n)

%Compute prepandicular direction to the slides
xm = mean(plans_x,1);
ym = mean(plans_y,1);
px = polyfit(sectionIndexInStack,xm,1);
py = polyfit(sectionIndexInStack,ym,1);
n = [px(1);py(1)]; n = n/norm(n);

for i=1:length(ii)
    
    %Extract data
    sp = singlePlanes(i);
    
    c = mean([sp.xIntercept_mm sp.yIntercept_mm],2); 
    slideCenter_mm(:,i) = c;
    d_mm(i) = sign(dot(c,n))*norm(c);
end

%% Compute sample-wide fits

%Rotation on x-y plane [deg]
rot = [singlePlanes.rotation_deg];
isRotOk = abs(rot-median(rot))<isRotOkThreshold; %Degrees, Rotation quality check

%Size change [%]
sc = [singlePlanes.sizeChange_precent];
isSCOk = abs(sc-median(sc))<isSCOkThreshold;% Percent, Size change quality check

isOk = isRotOk & isSCOk;

%Compute what is the last iteration that we have data for
lastIteration = max(hiJson.sectionIteration); %Last iteration that we have data of
if ~any(hiJson.sectionIteration(sectionIndexInStack) == lastIteration)
    warning('There are no slides with the last stack. I will assume there is a mistake and last iteration wasnt scanned yet');
    lastIteration = max(hiJson.sectionIteration(sectionIndexInStack));
end

%Predicted locations 
%Notice that sectionDepthsRequested_um has origin (0) at full face, so we
%need to convert to OCT at origin. We will use the first guess as means of
%convertion
d_mmP = (hiJson.sectionDepthsRequested_um(sectionIndexInStack) - hiJson.estimatedDepthOfOCTOrigin_um(lastIteration)) ...
    /1000; 
d_mmP = d_mmP(:)';
%d_mm  -actual locatios

%Position of the last position requested (new face)
d_mmPLast = (hiJson.sectionDepthsRequested_um(end) - hiJson.estimatedDepthOfOCTOrigin_um(lastIteration)) ...
    /1000;

%Try to estimate which d_mm are outliers by comparing their distance from
%expectation
tmp = d_mmP-d_mm; tmp = tmp-median(tmp);
isOk = isOk & (abs(tmp)<100e-3);

%Predicted vs actual locations. Offset and scale: d_mm = (d_mmP - offset)*scale
p = polyfit(d_mmP(isOk),d_mm(isOk),1);
scale = p(1);
offset = p(2)/scale;

if (abs(scale) > 1.5 || abs(scale) <1/1.5)
    warning('scale fit is out of proportion %.2f, expecting value to be 1+-10%%. Correcting scale to 1',scale);
    
    %Refit
    scale = 1;
    offset = median(d_mm(isOk)-d_mmP(isOk));
    p = [scale offset];
end
d_mmF = polyval(p,d_mmP); %Fit corrected values

%The position that is up to where we cut
d_mmFLast = polyval(p,d_mmPLast); 

%Compute distance from last slide to origin
distanceFromLastSlideToOrigin_mm = abs(d_mmFLast);
didLastSlidePassedOrigin = ~(abs(d_mmFLast) <= min(abs(d_mmF))); % 1 - we already passed origin

%Update our estimate of where OCT origin is compared to full face
%Update estimate for lastIteration+1
hiJson.estimatedDepthOfOCTOrigin_um(lastIteration+1) = ...
    hiJson.estimatedDepthOfOCTOrigin_um(lastIteration) - offset*1000;

%Compute full face position
ffd = -hiJson.estimatedDepthOfOCTOrigin_um(:)/1000;
ffx = n(1)*ffd + cos(median(rot)/180*pi)*lineLength/2*[1 -1]; 
ffy = n(2)*ffd + sin(median(rot)/180*pi)*lineLength/2*[1 -1];

%Check if we have enugh datapoints
if (sum(isOk) < length(isOk)/3 || sum(isOk)<2)
    warning('Not enugh good samples, everything seems to be an outlier');
    isProperStackAlignmentSuccess = false;
else
    isProperStackAlignmentSuccess = true;
end    

%% Generate stack alignment results data structure
SARS.sectionNames = sectionNames; %Section Names
SARS.isProperStackAlignmentSuccess = isProperStackAlignmentSuccess;
SARS.isOk = isOk; %isProperStackAlignment
SARS.XYRotMean_deg = mean(rot(isRotOk));
SARS.XYRotStd_deg  = std(rot(isRotOk));
SARS.sizeChangeMean_precent = mean(sc(isSCOk));
SARS.sizeChangeStd_precent  = std(sc(isSCOk));
SARS.meanSlideSeperation_um = abs(scale)*median(diff(hiJson.sectionDepthsRequested_um));
SARS.meanSlideSeperationSEM_um = ...
    std(d_mmF(isOk)-d_mm(isOk))/sqrt(sum(isOk))*1000; %Standard error of mean
SARS.distanceBetweenFullFaceAndOCTOrigin_um = ...
    hiJson.estimatedDepthOfOCTOrigin_um(lastIteration+1);
SARS.distanceBetweenFullFaceAndOCTOriginError_um = ... Error compared to prediction
    hiJson.estimatedDepthOfOCTOrigin_um(lastIteration+1) - hiJson.estimatedDepthOfOCTOrigin_um(1);
SARS.distanceFromLastSlideToOrigin_um = distanceFromLastSlideToOrigin_mm*1000;
SARS.didLastSlidePassedOrigin = didLastSlidePassedOrigin; %1 - yes

%% Plot Main Figure (#1)

%Reset figure
fig1=figure(100);
set(fig1,'units','normalized','outerposition',[0 0 1 1]);
subplot(1,1,1); %Clear previuse figure

%Plot Photobleached lines
subplot(2,2,1);
spfPlotTopView( ...
    singlePlanes,hLinePositions,vLinePositions, ...
    'lineLength',lineLength,'planeNames',sectionNames, ...
    'theDot',[octVolumeJson.theDotX; octVolumeJson.theDotY] ...
    );
if(SARS.isProperStackAlignmentSuccess)
    tmp = ', Alignment Success';
else
    tmp = ', Failed to Stack Align';
end
title([subjectName tmp]);

% Plot rotations
subplot(2,2,2);
plot(sectionIndexInStack(isRotOk),rot(isRotOk),'.')
hold on;
plot(sectionIndexInStack(~isRotOk),rot(~isRotOk),'.')
plot(sectionIndexInStack([1 end]),SARS.XYRotMean_deg*[1 1],'--r');
hold off;
ylabel('deg');
xlabel('Slide #');
title(sprintf('Rotation Angle: %.1f \\pm %.1f[deg]',SARS.XYRotMean_deg,SARS.XYRotStd_deg));
grid on;

%Plot size change 
subplot(2,2,4);
plot(sectionIndexInStack(isSCOk),sc(isSCOk),'.')
hold on;
plot(sectionIndexInStack(~isSCOk),sc(~isSCOk),'.')
plot(sectionIndexInStack([1 end]),SARS.sizeChangeMean_precent*[1 1],'--r');
hold off;
ylabel('%');
xlabel('Slide #');
title(sprintf('1D Pixel Size Change: %.1f \\pm %.1f [%%]', ...
    SARS.sizeChangeMean_precent,SARS.sizeChangeStd_precent));
grid on;

%Plot distance to origin
subplot(2,2,3);
plot(sectionIndexInStack,d_mmF,'--r');
hold on;
plot(sectionIndexInStack(isOk),d_mm(isOk),'.');
plot(sectionIndexInStack(~isOk),d_mm(~isOk),'.')
hold off;
ylabel('Distance [mm]');
xlabel('Slide #')
title('Distance From Origin');
grid on;
legend(...
    sprintf('%.0f\\mum/slide \\pm%.0f\\mum',...
    SARS.meanSlideSeperation_um, ...
    SARS.meanSlideSeperationSEM_um ...
    ),...
    'location','southeast');
title(sprintf('FF->OCT Origin Distance:\nInitial Guess: %.0fum, Latest Guess: %.0fum, Diff: %.1fum',...
    SARS.distanceBetweenFullFaceAndOCTOrigin_um - SARS.distanceBetweenFullFaceAndOCTOriginError_um, ...
    SARS.distanceBetweenFullFaceAndOCTOrigin_um, ...
    SARS.distanceBetweenFullFaceAndOCTOriginError_um));

%% Plot Main Figure (#2)

%Plot top view in a new figure with enface under it
fig2=figure(42);
set(fig2,'units','normalized','outerposition',[0 0 1 1]);
subplot(1,1,1); %Clear previuse figure
spfPlotTopView( ...
    singlePlanes,hLinePositions,vLinePositions, ...
    'lineLength',lineLength,'planeNames',sectionNames, ...
    'theDot',[octVolumeJson.theDotX; octVolumeJson.theDotY],...
    'enfaceViewImage',enfaceView, ...
    'enfaceViewImageXLim', [min(octVolumeJson.overview.xCenters) max(octVolumeJson.overview.xCenters)] + octVolumeJson.overview.range*[-1/2 1/2],...
    'enfaceViewImageYLim', [min(octVolumeJson.overview.yCenters) max(octVolumeJson.overview.yCenters)] + octVolumeJson.overview.range*[-1/2 1/2] ...
    );

%Plot full face plane
hold on;
h = plot(ffx',ffy','--w','LineWidth',2);
for i=1:size(ffx,1)
   text(ffx(i,1),ffy(i,1),sprintf('Guess #%d',i-1),'Color','w');
end
%set(h, {'color'}, num2cell(winter(size(ffx,1)),2)); %Set multiple colors
hold off;

%% Print a report for user & google doc
if (SARS.isProperStackAlignmentSuccess)
    %% Print a report for user & google doc - alignment success case
    %Information about the stack
    ang = SARS.XYRotMean_deg;
    if (ang<0)
        ang = ang+180;
    end
    json1 = sprintf(['{"Table":"SamplesRunsheet","SampleID":"%s",' ...
        '"Slide Seperation um":%.2f,' ...
        '"FF to Origin Initial Guess um":%.1f,"FF to Origin Updated Guess um":%.1f,' ...
        '"XY Angle deg":%.1f,"Size Change Percent":%.1f}'],...
        subjectName, ...
        SARS.meanSlideSeperation_um, ...
        SARS.distanceBetweenFullFaceAndOCTOrigin_um - SARS.distanceBetweenFullFaceAndOCTOriginError_um, SARS.distanceBetweenFullFaceAndOCTOrigin_um, ...
        SARS.XYRotMean_deg,SARS.sizeChangeMean_precent ...
        );
    
    %Loop over each slide
    json2 = '';
    for i=1:length(SARS.isOk)
        if (SARS.isOk(i))
            status = 'Yes';
        else
            status = 'No';
        end
        
        json2 = sprintf(['%s,{"Table":"SlidesRunsheet",' ...
            '"Full Slide Name":"%s-%s",' ...
            '"Proper Alignment Wth Stack?":"%s","Distance From Origin [um]":"%.0f"}'], ...
            json2, ...
            subjectName,sectionNames{i}, ...
            status, abs(d_mmF(i)*1000) ...
            );       
    end
    
else
    %% Print a report for user & google doc - alignment failure case
    disp('Stack Alignment Failed');
    json1 = sprintf(['{"Table":"SamplesRunsheet","SampleID":"%s",' ...
        '"Slide Seperation um":"NA",' ...
        '"FF to Origin Initial Guess um":"NA","FF to Origin Updated Guess um":"NA",' ...
        '"XY Angle deg":"NA","Size Change Percent":"NA"}'],...
        subjectName ...
        );
    json2 = '';
    for i=1:length(SARS.isOk)
        json2 = sprintf(['%s,{"Table":"SlidesRunsheet",' ...
            '"Full Slide Name":"%s-%s",' ...
            '"Proper Alignment Wth Stack?":"No","Distance From Origin [um]":"%.0f"}'], ...
             json2, ...
             subjectName,sectionNames{i}, ...
             abs(d_mmF(i)*1000) ...
             );
    end
end
%Generate full json
jsonTxt = [ '{"Items":[' json1 json2 ']}'];
jsonTxt = urlencode(jsonTxt);
lk = sprintf('%s%s',...
    'https://docs.google.com/forms/d/e/1FAIpQLSc1kQcXdVBJogFOo2Tt2eCjPh3Cq6kmjCOLL2em0eQZGO8lJw/viewform?usp=pp_url&entry.1224635255=',...
    jsonTxt);

%Create a link for user
fprintf('\n\nSubmit Changes Online:\n %s\n',lk);
fid = fopen('lk.txt','w');
fprintf(fid,'%s',lk);
fclose(fid);

d = SARS.distanceFromLastSlideToOrigin_um;
if SARS.didLastSlidePassedOrigin == 1
    d = -d;
end
fprintf('Distance from current face to origin (negative number means we surpassed origin):\n\t%.0f [um]\n',...
    d);

%Save it to a file for downstream automated usage
fid = fopen('DistanceFromCurrentFaceToOriginUM.txt','w');
fprintf(fid,'%.0f',d);
fclose(fid);

%% Update data to the cloud

%Save images to log
if ~isempty(logFolder)
    saveas(fig2,'StackAlignmentFigure2.png');
    saveas(fig1,'StackAlignmentFigure1.png');

    awsCopyFileFolder('StackAlignmentFigure1.png',[logFolder '/StackAlignmentFigure1.png']);
    awsCopyFileFolder('StackAlignmentFigure2.png',[logFolder '/StackAlignmentFigure2.png']);
    
    %Log results
    awsWriteJSON(SARS,[logFolder '/StackAlignmentResults.json']);
end

%Update histology instructions with our updated guess of where OCT origin is
awsWriteJSON(hiJson,hiJsonFilePath);