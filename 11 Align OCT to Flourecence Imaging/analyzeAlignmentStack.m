% This script loads all slides of one subject, compute trends
%run this script twice to correct slide alignment based on stack trned

%% Inputs
%Set to true if you would like these results to be saved to the cloud,
%false if saved locally only
isUpdateCloud = false; 

subjectFolder = s3SubjectPath('03');
if exist('subjectFolder_','var')
    subjectFolder = subjectFolder_; %JSON
    isUpdateCloud = true;
end

%If not empty, will write the overview files to Log Folder
logFolder = awsModifyPathForCompetability([subjectFolder '/Log/11 Align OCT to Flourecence Imaging/']);
%logFolder = [];

usableArea = 0.55; %mm - how close should section be to origin to be 'usable'

%% Find all JSONS
awsSetCredentials(1);
subjectFolder = awsModifyPathForCompetability(subjectFolder);
[~,subjectName] = fileparts([subjectFolder(1:end-1) '.a']);

disp([datestr(now) ' Loading JSONs']);

%OCT
octVolumeJsonFilePath = awsModifyPathForCompetability([subjectFolder '/OCTVolumes/ScanConfig.json']);
octVolumeJson = awsReadJSON(octVolumeJsonFilePath);

%Sections
sectionJsonFilePaths = s3GetAllSlidesOfSubject(subjectFolder);
sectionJsonFilePaths = cellfun(@(x)([x 'SlideConfig.json']),sectionJsonFilePaths,'UniformOutput',false);
sectionJsons = cell(size(sectionJsonFilePaths));
for i=1:length(sectionJsons)
    sectionJsons{i} = awsReadJSON(sectionJsonFilePaths{i});
end

%Histology Instructions
hiJsonFilePath = awsModifyPathForCompetability([subjectFolder '/Slides/HistologyInstructions.json']);
hiJson = awsReadJSON(hiJsonFilePath);

%% Load enface view if avilable 
disp([datestr(now) ' Loading Enface View']);

enfaceFilePath = awsModifyPathForCompetability( ...
    [subjectFolder '/OCTVolumes/OverviewScanAbs_Enface.tif']);
if awsExist(enfaceFilePath,'file')
    ds = fileDatastore(enfaceFilePath,'ReadFcn',@yOCTFromTif);
    enfaceView = ds.read();
else
    enfaceView = [];
end

%% General data
disp([datestr(now) ' Computing...']);

sectionNames = hiJson.sectionName;
singlePlaneFits = cell(size(sectionNames));
for i=1:length(singlePlaneFits)
    jsonIndex = find(cellfun(@(x)(contains(x,sectionNames{i})), ...
        sectionJsonFilePaths));
    
    if (length(jsonIndex) > 1)
        error('Too many hits in find planes');
    end
    
    if ~isempty(jsonIndex)
        %Found json, see if it was analyized
        if isfield(sectionJsons{jsonIndex}.FM,'singlePlaneFit')
            singlePlaneFits{jsonIndex} = ...
                sectionJsons{jsonIndex}.FM.singlePlaneFit;
        end
    end
end

pixelsSize_um = sectionJsons{1}.FM.pixelSize_um;

%Get H&V lines positions
if isfield(octVolumeJson,'version') && octVolumeJson.version == 2
    vLinePositions = octVolumeJson.photobleach.vLinePositions;
    hLinePositions = octVolumeJson.photobleach.hLinePositions;
    lineLength = octVolumeJson.photobleach.lineLength;
else
    vLinePositions = octVolumeJson.vLinePositions;
    hLinePositions = octVolumeJson.hLinePositions;
    lineLength = octVolumeJson.lineLength;
end

%% Fit stack (by iteration)
nIterations = max(hiJson.sectionIteration);
singlePlaneFits_Realigned = cell(size(singlePlaneFits));
singlePlaneFits_IsOutlier = zeros(size(singlePlaneFits));
singlePlaneFits_IsUsableSlide = zeros(size(singlePlaneFits)); %In case there is an outlier, but still we can use this
for i=1:nIterations
    ii = hiJson.sectionIteration == i;
    [singlePlaneFits_Realigned(ii),singlePlaneFits_IsOutlier(ii)] = ...
        spfRealignByStack(singlePlaneFits(ii), ...
        hiJson.sectionDepthsRequested_um(ii)/1000);
    
    if (sum(singlePlaneFits_IsOutlier(ii)) == sum(ii))
        %All planes are outliers, the alignment failed, this is not usable
        singlePlaneFits_IsUsableSlide(ii) = false;
    else
        singlePlaneFits_IsUsableSlide(ii) = true;
    end
end

noFit = cellfun(@isempty,singlePlaneFits);
goodFit  = ~singlePlaneFits_IsOutlier & singlePlaneFits_IsUsableSlide & ~noFit;
maybeFit =  singlePlaneFits_IsOutlier & singlePlaneFits_IsUsableSlide & ~noFit;
badFit   = ~singlePlaneFits_IsUsableSlide & ~noFit;

%% Plot Main Figure (#1)

%Get data required for the plot
index = 1:length(singlePlaneFits);
rot = NaN*zeros(size(singlePlaneFits));
rot(~noFit) = cellfun(@(x)(x.rotation_deg),singlePlaneFits(~noFit));
rot_realigned = NaN*zeros(size(singlePlaneFits));
rot_realigned(~noFit) = cellfun(@(x)(x.rotation_deg),singlePlaneFits_Realigned(~noFit));
sc = NaN*zeros(size(singlePlaneFits));
sc(~noFit) = cellfun(@(x)(norm(x.u)),singlePlaneFits(~noFit))*1e3; %um
sc = 100*(pixelsSize_um./sc - 1);
sc_realigned = NaN*zeros(size(singlePlaneFits));
sc_realigned(~noFit)  = cellfun(@(x)(norm(x.u)),singlePlaneFits_Realigned(~noFit))*1e3; %um
sc_realigned = 100*(pixelsSize_um./sc_realigned - 1);
d = NaN*zeros(size(singlePlaneFits));
d(~noFit) = cellfun(@(x)(dot(cross(x.u,x.v)/(norm(x.u)*norm(x.v)),x.h)),singlePlaneFits(~noFit)); %mm
d_realigned = NaN*zeros(size(singlePlaneFits));
d_realigned(~noFit)  = cellfun(@(x)(x.d),singlePlaneFits_Realigned(~noFit)); %mm

%Reset figure
fig1=figure(100);
set(fig1,'units','normalized','outerposition',[0 0 1 1]);
subplot(1,1,1); %Clear previuse figure

%Plot Photobleached lines
subplot(2,2,1);
spfPlotTopView( ...
    singlePlaneFits,hLinePositions,vLinePositions, ...
    'lineLength',lineLength,'planeNames',sectionNames, ...
    'theDot',[octVolumeJson.theDotX; octVolumeJson.theDotY] ...
    );
title([subjectName]);

% Plot rotations
s = sqrt(mean( ( rot(goodFit) - rot_realigned(goodFit) ).^2));
subplot(2,2,2);
plot(index(goodFit),rot(goodFit),'.');
hold on;
plot(index(maybeFit | badFit),  rot(maybeFit | badFit),'.');
plot(index(goodFit | maybeFit), rot_realigned(goodFit | maybeFit), '--r');
hold off;
ylabel('deg');
xlabel('Slide #');
title(sprintf('Rotation Angle: %.1f \\pm %.1f[deg]',nanmean(rot_realigned),s));
grid on;

%Plot size change 
s = sqrt(mean( ( sc(goodFit) - sc_realigned(goodFit) ).^2));
subplot(2,2,4);
plot(index(goodFit),sc(goodFit),'.');
hold on;
plot(index(maybeFit | badFit),  sc(maybeFit | badFit),'.');
plot(index(goodFit | maybeFit), sc_realigned(goodFit | maybeFit), '--r');
hold off;
ylabel('%');
xlabel('Slide #');
title(sprintf('1D Pixel Size Change: %.1f \\pm %.1f [%%]', ...
    nanmean(sc_realigned),s));
grid on;

%Plot distance to origin
s = sqrt(nanmean( ( d(goodFit) - d_realigned(goodFit) ).^2));
f = (d_realigned(1) > 0)*(-2)+1;
subplot(2,2,3);
plot(index(goodFit),d(goodFit)*f,'.');
hold on;
plot(index(maybeFit | badFit),  d(maybeFit | badFit)*f,'.');
plot(index(goodFit | maybeFit), d_realigned(goodFit | maybeFit)*f, '--r');
hold off;
ylabel('Distance [mm]');
xlabel('Slide #');
title(sprintf('Distance From Origin, SEM %.1f[\\mum], Section Size: %.1f[\\mum]',s*1e3/sqrt(sum(goodFit)),...
    nanmedian(diff(d_realigned*f))*1e3 ));
grid on;

%If transision between iteration #1 and #2 exist, say what it is
last1 = find(hiJson.sectionIteration==1,1,'last');
if (sum(badFit(hiJson.sectionIteration==1))>0)
    last1 = [];
end
first2 = find(hiJson.sectionIteration==2,1,'first');
if (sum(badFit(hiJson.sectionIteration==2))>0)
    first2 = [];
end
if ~isempty(last1) && ~isempty(first2) 
    ii = [last1 first2];
    text(...
        mean(ii), ...
        mean(d_realigned(ii))+0.2, ...
        sprintf('Section Jump: %.0f\\mum',abs(diff(d_realigned(ii)))*1e3) ...
        );
end

%% Plot Main Figure (#2)

%Plot top view in a new figure with enface under it
fig2=figure(42);
set(fig2,'units','normalized','outerposition',[0 0 1 1]);
subplot(1,1,1); %Clear previuse figure
spfPlotTopView( ...
    singlePlaneFits,hLinePositions,vLinePositions, ...
    'lineLength',lineLength,'planeNames',sectionNames, ...
    'theDot',[octVolumeJson.theDotX; octVolumeJson.theDotY],...
    'enfaceViewImage',enfaceView, ...
    'enfaceViewImageXLim', [min(octVolumeJson.overview.xCenters) max(octVolumeJson.overview.xCenters)] + octVolumeJson.overview.range*[-1/2 1/2],...
    'enfaceViewImageYLim', [min(octVolumeJson.overview.yCenters) max(octVolumeJson.overview.yCenters)] + octVolumeJson.overview.range*[-1/2 1/2] ...
    );

%set(h, {'color'}, num2cell(winter(size(ffx,1)),2)); %Set multiple colors
hold off;

%% Print a report for user & google doc
disTextum = arrayfun(@(x)sprintf('%.0f',x),abs(d_realigned*1000),'UniformOutput',false);
disTextum(isnan(d_realigned)) = {'""'};
isProperStackAlignmentSuccess = sum(~badFit) > 1; %Alignment succeeded if at least one slide is aligned
if (isProperStackAlignmentSuccess)
    %% Print a report for user & google doc - alignment success case
    %Information about the stack
    ang = mean(rot_realigned);
    if (ang<0)
        ang = ang+180;
    end
    json1 = sprintf(['{"Table":"SamplesRunsheet","SampleID":"%s",' ...
        '"Slide Seperation um":%.2f,' ...
        '"XY Angle deg":%.1f,"Size Change Percent":%.1f}'],...
        subjectName, ...
        abs(median(diff(d_realigned)))*1e3, ...
        ang,mean(sc_realigned) ...
        );
    
    %Loop over each slide
    json2 = '';
    for i=1:length(goodFit)
        if (goodFit(i))
            status = 'Yes';
        elseif maybeFit(i)
            status = 'Maybe';
        else
            status = 'No';
        end
        
        json2 = sprintf(['%s,{"Table":"SlidesRunsheet",' ...
            '"Full Slide Name":"%s-%s",' ...
            '"Proper Alignment Wth Stack?":"%s","Distance From Origin [um]":%s}'], ...
            json2, ...
            subjectName,sectionNames{i}, ...
            status, disTextum{i} ...
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
            '"Proper Alignment Wth Stack?":"No","Distance From Origin [um]":%s}'], ...
             json2, ...
             subjectName,sectionNames{i}, ...
             disTextum{i} ...
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

d_lastSlide = abs(d_realigned(end));
direction = sign(median(diff(d_realigned)));
if (sign(d_realigned(end)) == sign(direction))
    %Cutting more slices will increase our position - we passed origin
    d_lastSlide = -d_lastSlide;
end
fprintf('Distance from current face to origin (negative number means we surpassed origin):\n\t%.0f [um]\n',...
    d_lastSlide*1e3);

%Save it to a file for downstream automated usage
fid = fopen('DistanceFromCurrentFaceToOriginUM.txt','w');
fprintf(fid,'%.0f',d);
fclose(fid);

%% Update data to the cloud
if isUpdateCloud
    disp('Uploading images to cloud ...');
    %Save images to log
    if ~isempty(logFolder)
        saveas(fig2,'StackAlignmentFigure2.png');
        saveas(fig1,'StackAlignmentFigure1.png');

        awsCopyFileFolder('StackAlignmentFigure1.png',[logFolder '/StackAlignmentFigure1.png']);
        awsCopyFileFolder('StackAlignmentFigure2.png',[logFolder '/StackAlignmentFigure2.png']);

    end
    
    %Update histology instructions with our updated guess of where OCT origin is
    %awsWriteJSON(hiJson,hiJsonFilePath); %TBD
    
    disp ('Done');
end