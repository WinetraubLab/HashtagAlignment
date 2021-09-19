% This script loads all slides of one subject, compute trends
%run this script twice to correct slide alignment based on stack trned

%% Inputs
%Set to true if you would like these results to be saved to the cloud,
%false if saved locally only
isUpdateCloud = false; 

subjectFolder = s3SubjectPath('21','LFM');
if exist('subjectFolder_','var')
    subjectFolder = subjectFolder_; %Jenkins
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
stackConfigFilePath = awsModifyPathForCompetability([subjectFolder '/Slides/StackConfig.json']);
scJson = awsReadJSON(stackConfigFilePath);

%% Check Histology Instructions for consistency
l1 = length(scJson.sections.names);
l2 = length(scJson.sections.iterations);
tmp = {scJson.histologyInstructions.iterations.sectionDepthsRequested_um};
tmp = cellfun(@(x)(x(:)'),tmp,'UniformOutput',false);
l3 = length([tmp{:}]);

if (std([l1 l2 l3]) ~= 0)
    error('Expecting Histology Instuctions to match between number of slides in: sections.names, sections.iterations, histologyInstructions.iterations.sectionDepthsRequested_um');
end

%% Load enface view if avilable 
disp([datestr(now) ' Loading Enface View']);

enfaceFilePath = awsModifyPathForCompetability( ...
    [subjectFolder '/OCTVolumes/OverviewScanAbs_Enface.tif']);
if awsExist(enfaceFilePath,'file')
    % Any fileDatastore request to AWS S3 is limited to 1000 files in 
    % MATLAB 2021a. Due to this bug, we have replaced all calls to 
    % fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
    % 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
    ds = imageDatastore(enfaceFilePath,'ReadFcn',@yOCTFromTif);
    enfaceView = ds.read();
else
    enfaceView = [];
end

%% General data
disp([datestr(now) ' Computing...']);

sectionNames = scJson.sections.names;
singlePlaneFits = cell(size(sectionNames));
for i=1:length(sectionNames)
    jsonIndex = find(cellfun(@(x)(contains(x,sectionNames{i})), ...
        sectionJsonFilePaths));
    
    if (length(jsonIndex) > 1)
        error('Too many hits in find planes');
    end
    
    if ~isempty(jsonIndex)
        %Found json, see if it was analyized
        if isfield(sectionJsons{jsonIndex}.FM,'singlePlaneFit')
            singlePlaneFits{i} = ...
                sectionJsons{jsonIndex}.FM.singlePlaneFit;
        end
        
        pixelsSize_um = sectionJsons{jsonIndex}.FM.pixelSize_um;
    end
end
isAnyAlignedSections = ~isempty(sectionJsons);
if ~isAnyAlignedSections
    % No way to aligned.
    disp('No alignable slides. exiting');
    
    % Write data to file as well for downstream
    leaveJsonData ('',NaN);
    return;
end


%Get H&V lines positions
if isfield(octVolumeJson,'version') && ...
        (octVolumeJson.version == 2 || octVolumeJson.version == 2.1 || ...
        octVolumeJson.version == 2.2)
    vLinePositions = octVolumeJson.photobleach.vLinePositions;
    hLinePositions = octVolumeJson.photobleach.hLinePositions;
    lineLength = octVolumeJson.photobleach.lineLength;
else
    vLinePositions = octVolumeJson.vLinePositions;
    hLinePositions = octVolumeJson.hLinePositions;
    lineLength = octVolumeJson.lineLength;
end

%% Fit stack (by iteration)
nIterations = length(scJson.histologyInstructions.iterations);
singlePlaneFits_Realigned = cell(size(singlePlaneFits));
singlePlaneFits_IsOutlier = zeros(size(singlePlaneFits));
singlePlaneFits_IsUsableSlide = zeros(size(singlePlaneFits)); %In case there is an outlier, but still we can use this
for i=1:nIterations
    fprintf('Computing iteration %d ...\n',i);
    
    ii = scJson.sections.iterations == i;
    [singlePlaneFits_Realigned(ii),singlePlaneFits_IsOutlier(ii),nOut,sectionDistanceToOriginOut,averagePixelSize_um] = ...
        spfComputeStackAverageAndRealign(singlePlaneFits(ii), ...
        scJson.histologyInstructions.iterations(i).sectionDepthsRequested_um/1000);
    
    if (sum(singlePlaneFits_IsOutlier(ii)) == sum(ii))
        % All planes are outliers, the alignment failed, this is not usable
        singlePlaneFits_IsUsableSlide(ii) = false;
        nOut = [];
        sectionDistanceToOriginOut = NaN*zeros(sum(ii),1);
    else
        singlePlaneFits_IsUsableSlide(ii) = true;
    end
    
    % Compute scale factor
    FM_pixelSize_um = mean(cellfun(@(x)(x.FM.pixelSize_um),sectionJsons));
    scaleFactor = FM_pixelSize_um/averagePixelSize_um;
    
    % Is plane normal in the same direction as the histology cutting 
    % (doesn't have to be this way!)
    if ~isempty(nOut)
        cutDirection = [octVolumeJson.theDotX; octVolumeJson.theDotY; 0] * ...
            (-scJson.histologyInstructions.iterations(i).startCuttingAtDotSide);
        isPlaneNormalSameDirectionAsCuttingDirection = sign(dot(cutDirection,nOut));
    else
        isPlaneNormalSameDirectionAsCuttingDirection = [];
    end
    
    % Update stack config to show stack alignment result
    scJson.stackAlignment(i).planeNormal = nOut;
    scJson.stackAlignment(i).isPlaneNormalSameDirectionAsCuttingDirection = isPlaneNormalSameDirectionAsCuttingDirection;
    scJson.stackAlignment(i).planeDistanceFromOCTOrigin_um = sectionDistanceToOriginOut*1000;
    scJson.stackAlignment(i).wasSectionUsedInComputingStackAlignment = ~singlePlaneFits_IsOutlier(ii);
    scJson.stackAlignment(i).scaleFactor = scaleFactor;
    scJson.stackAlignment(i).notes = sprintf([ ...
        'planeNormal - unit vector, parallel to the average normal of the slide planes. Each slide plane norm is -u X v.\n' ...
        'isPlaneNormalSameDirectionAsCuttingDirection - There are two histology ''normal'' defenitions: ' ...
        ' (1) Direction that the histologist advances with every slide cut. This is determined by whether we start cutting from the dot.\n' ...
        ' (2) Direction that is - u X v which depends on how slides was scanned.\n' ...
        ' isPlaneNormalSameDirectionAsCuttingDirection = 1 if both (1) and (2) point in the same direction, i.e parallel.\n' ...
        ' isPlaneNormalSameDirectionAsCuttingDirection = -1 if (1) and (2) point in opposite directions, i.e. anti-parallel.\n' ...
        'planeDistanceFromOCTOrigin_um - Starting from OCT origin (0,0,0), going along the planeNormal direction, ' ...
            'what is the distance you cross each plane. This is an approximation for planes'' distance from origin, ' ...
            'but using the average normal.\n' ...
            ' Notice #1: This distance can be negative if to cross the plane we had to walk along -planeNormal.\n' ...
            ' Notice #2: Multiply planeDistanceFromOCTOrigin_um by isPlaneNormalSameDirectionAsCuttingDirection to get an estimate of ' ...
             'planes'' order in the stack, if started cutting from dot side, negative distances are cut before positve ones.\n' ...
        'wasSectionUsedInComputingStackAlignment - was this section used when computing stack alignment? If set to false it means this section is probably outlier and was skipped.\n' ...
        'scaleFactor - average sample shrinkage (if scaleFactor <1) or expansion of the stack. Scale factor can be seen as: fluorescenceMicroscopePixelSize (imaging device''s pixel size) = average(|u|)*scaleFactor\n' ...
        ]);
end
fprintf('Done!\n');

noFit = cellfun(@isempty,singlePlaneFits);
goodFit  = ~singlePlaneFits_IsOutlier & singlePlaneFits_IsUsableSlide & ~noFit;
maybeFit =  singlePlaneFits_IsOutlier & singlePlaneFits_IsUsableSlide;
badFit   = ~singlePlaneFits_IsUsableSlide;

% We would like the drawing to be from 'lower numbers' growing so flip axis if needed
tmp = [scJson.stackAlignment(:).isPlaneNormalSameDirectionAsCuttingDirection];
if ~isempty(tmp)
    isPlaneNormalSameDirectionAsCuttingDirection = median(tmp); 
else
    isPlaneNormalSameDirectionAsCuttingDirection = 1;
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
    'isStartCuttingFromDotSide',scJson.histologyInstructions.iterations(1).startCuttingAtDotSide, ...
    'enfaceViewImage',enfaceView, ...
    'enfaceViewImageXLim', [min(octVolumeJson.overview.xCenters) max(octVolumeJson.overview.xCenters)] + octVolumeJson.overview.range*[-1/2 1/2],...
    'enfaceViewImageYLim', [min(octVolumeJson.overview.yCenters) max(octVolumeJson.overview.yCenters)] + octVolumeJson.overview.range*[-1/2 1/2] ...
    );
title(subjectName);

%set(h, {'color'}, num2cell(winter(size(ffx,1)),2)); %Set multiple colors
hold off;

%% Plot Main Figure (#1)

%Get data required for the plot
index = 1:length(singlePlaneFits);
rot = NaN*zeros(size(singlePlaneFits));
rot(~noFit) = cellfun(@(x)(x.rotation_deg),singlePlaneFits(~noFit));
rot_realigned = NaN*zeros(size(singlePlaneFits));
rot_realigned(~badFit) = cellfun(@(x)(x.rotation_deg),singlePlaneFits_Realigned(~badFit));
tilt = NaN*zeros(size(singlePlaneFits));
tilt(~noFit) = cellfun(@(x)(x.tilt_deg),singlePlaneFits(~noFit));
tilt_realigned = NaN*zeros(size(singlePlaneFits));
tilt_realigned(~badFit) = cellfun(@(x)(x.tilt_deg),singlePlaneFits_Realigned(~badFit));
sc = NaN*zeros(size(singlePlaneFits));
sc(~noFit) = cellfun(@(x)(norm(x.u)),singlePlaneFits(~noFit))*1e3; %um
sc = 100*(pixelsSize_um./sc - 1);
sc_realigned = NaN*zeros(size(singlePlaneFits));
sc_realigned(~badFit) = cellfun(@(x)(norm(x.u)),singlePlaneFits_Realigned(~badFit))*1e3; %um
sc_realigned = 100*(pixelsSize_um./sc_realigned - 1);
d_singlePlaneFit = NaN*zeros(size(singlePlaneFits));
for i=1:length(noFit)
    if ~noFit(i)
        d_singlePlaneFit(i) = dot(singlePlaneFits_Realigned{i}.normal,singlePlaneFits{i}.h);
        %d_singlePlaneFit(i) = dot(singlePlaneFits{i}.normal,singlePlaneFits{i}.h);
    end
end
d_stackPlaneFit = NaN*zeros(size(singlePlaneFits));
d_stackPlaneFit(~badFit)  = cellfun(@(x)(x.d),singlePlaneFits_Realigned(~badFit)); %mm
% Notice, some nan values exist for 
%   - slides with no data but only before the fit
%   - in case fit failed for some slides

sectionIterations = scJson.sections.iterations;

%Reset figure
fig1=figure(100);
set(fig1,'units','normalized','outerposition',[0 0 1 1]);
subplot(1,1,1); %Clear previuse figure

%Plot Photobleached lines
subplot(2,3,1);
spfPlotTopView( ...
    singlePlaneFits,hLinePositions,vLinePositions, ...
    'lineLength',lineLength,'planeNames',sectionNames, ...
    'theDot',[octVolumeJson.theDotX; octVolumeJson.theDotY], ...
    'isStartCuttingFromDotSide',scJson.histologyInstructions.iterations(1).startCuttingAtDotSide);
title(subjectName);

% Plot rotations
s = sqrt(mean( ( rot(goodFit) - rot_realigned(goodFit) ).^2));
subplot(2,3,2);
plotPerIteration(index,rot,sectionIterations,goodFit,'#0072BD');
hold on;
plotPerIteration(index,rot,sectionIterations,maybeFit | badFit,'#D95319');
hold on;
plotPerIteration(index,rot_realigned,sectionIterations, noFit,'k');
hold on;
plot(index, rot_realigned, '--r');
hold off;
ylabel('deg');
setSectionNamesAsXLabels(scJson.sections.names); 
title(sprintf('Rotation Angle: %.1f \\pm %.1f[deg]\nRotating Along Z Axis',nanmean(rot_realigned),s));
grid on;

% Plot tilts
s = sqrt(mean( ( tilt(goodFit) - tilt_realigned(goodFit) ).^2));
subplot(2,3,3);
plotPerIteration(index,tilt,sectionIterations,goodFit,'#0072BD');
hold on;
plotPerIteration(index,tilt,sectionIterations,maybeFit | badFit,'#D95319');
hold on;
plotPerIteration(index,tilt_realigned,sectionIterations, noFit,'k');
hold on;
plot(index, tilt_realigned, '--r');
hold off;
ylabel('deg');
setSectionNamesAsXLabels(scJson.sections.names); 
title(sprintf('Tilt Angle: %.1f \\pm %.1f[deg]\nRotating Along Y Axis',nanmean(tilt_realigned),s));
grid on;

%Plot size change 
s = sqrt(mean( ( sc(goodFit) - sc_realigned(goodFit) ).^2));
subplot(2,3,5);
hold on;
plotPerIteration(index,sc,sectionIterations,goodFit,'#0072BD');
hold on;
plotPerIteration(index,sc,sectionIterations,maybeFit | badFit,'#D95319');
hold on;
plotPerIteration(index,sc_realigned,sectionIterations, noFit,'k');
hold on;
plot(index, sc_realigned, '--r');
hold off;
ylabel('%');
setSectionNamesAsXLabels(scJson.sections.names); 
title(sprintf('1D Pixel Size Change: %.1f \\pm %.1f [%%]', ...
    nanmean(sc_realigned),s));
grid on;

%Plot distance to origin
s = sqrt(nanmean( ( d_singlePlaneFit(goodFit) - d_stackPlaneFit(goodFit) ).^2));
isStartCuttingFromDotSide = scJson.histologyInstructions.iterations(1).startCuttingAtDotSide;
subplot(2,3,4);
plotPerIteration(index,d_singlePlaneFit,sectionIterations,goodFit,'#0072BD');
hold on;
plotPerIteration(index,d_singlePlaneFit,sectionIterations,maybeFit | badFit,'#D95319');
hold on;
plotPerIteration(index,d_stackPlaneFit,sectionIterations, noFit,'k');
hold on;
plot(index, d_stackPlaneFit, '--r');
hold off;
ylabel('Distance [mm]');
setSectionNamesAsXLabels(scJson.sections.names); 
title(sprintf('Distance From Origin, SEM %.1f[\\mum], Section Size: %.1f[\\mum]',s*1e3/sqrt(sum(goodFit)),...
    nanmedian(abs(diff(d_stackPlaneFit*isPlaneNormalSameDirectionAsCuttingDirection))*1e3) ));
grid on;
if isPlaneNormalSameDirectionAsCuttingDirection == 1
    set(gca, 'YDir','reverse');
else
    set(gca, 'YDir','normal');
end
%if isStartCuttingFromDotSide == 1
%    set(gca, 'XDir','normal');
%else
%    set(gca, 'XDir','reverse');
%end

%If transision between iteration #1 and #2 exist, say what it is
last1 = find(scJson.sections.iterations==1,1,'last');
if (sum(badFit(scJson.sections.iterations==1))>0)
    last1 = [];
end
first2 = find(scJson.sections.iterations==2,1,'first');
if (sum(badFit(scJson.sections.iterations==2))>0)
    first2 = [];
end
if ~isempty(last1) && ~isempty(first2) 
    ii = [last1 first2];
    text(...
        mean(ii), ...
        mean(d_stackPlaneFit(ii))+0.2, ...
        sprintf('Section Jump: %.0f\\mum',abs(diff(d_stackPlaneFit(ii)))*1e3) ...
        );
end

subplot(2,3,6)
plot(NaN, [NaN NaN],'.'); hold on; plot(NaN,NaN,'.k'); 
plot(NaN,NaN,'.','Color','#0072BD'); 
plot(NaN,NaN,'o','Color','#0072BD','MarkerSize',4); 
plot(NaN,NaN,'d','Color','#0072BD','MarkerSize',4)
legend('Good Alignment','Bad Alignment','No Alignment, Set to Default', ...
       '1^{st} Iteration','2^{nd} Iteration','3^{rd} Iteration',...
       'Location','SouthEast');
axis off

%% Print a report for user & google doc
disTextum = arrayfun(@(x)sprintf('%.0f',x),abs(d_stackPlaneFit*1000),'UniformOutput',false);
disTextum(isnan(d_stackPlaneFit)) = {'""'};
isProperStackAlignmentSuccess = sum(~badFit) > 1; %Alignment succeeded if at least one slide is aligned
if (isProperStackAlignmentSuccess)
    %% Print a report for user & google doc - alignment success case
    %Information about the stack
    ang = nanmean(rot_realigned);
    if (ang<0)
        ang = ang+180;
    end
    json1 = sprintf(['{"Table":"SamplesRunsheet","SampleID":"%s",' ...
        '"Slide Seperation um":%.2f,' ...
        '"XY Angle deg":%.1f,"Size Change Percent":%.1f}'],...
        subjectName, ...
        abs(nanmedian(diff(d_stackPlaneFit)))*1e3, ...
        ang,nanmean(sc_realigned) ...
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
    for i=1:length(goodFit)
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

% Measure distance from last slide to origin.
% We would like this number to be positive if we didn't surpass origin yet,
% negative if we surpased. This means d_lastSlide is computed in the
% anti-parallel direction to the cuting direction.
% Comparing the anti-parallel to cutting with the normal to plane to the
% histology cuts is: (-isPlaneNormalSameDirectionAsCuttingDirection)
d_lastSlide = (-isPlaneNormalSameDirectionAsCuttingDirection) * d_stackPlaneFit(end);
fprintf('Distance from current face to origin (negative number means we surpassed origin):\n\t%.0f [um]\n',...
    d_lastSlide*1e3);

% Write data to file as well for downstream
leaveJsonData (lk,d_lastSlide)

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
    
    % Update stack config
    awsWriteJSON(scJson,stackConfigFilePath);
    
    disp ('Done');
end


%% Helper function to generate Json handles
function leaveJsonData (lk,d_lastSlide_mm)
% lk - link for submitting changes online

%Create a link for user
fid = fopen('lk.txt','w');
fprintf(fid,'%s',lk);
fclose(fid);

%Save distance from current face to origion.
fid = fopen('DistanceFromCurrentFaceToOriginUM.txt','w');
fprintf(fid,'%.0f',d_lastSlide_mm*1e3);
fclose(fid);
end

%% Helper function to plot different iterations in different dot shape
function plotPerIteration(xAxis,yAxis,iterations,isPlotThatPoint,color)

plot(xAxis(isPlotThatPoint & iterations==1),yAxis(isPlotThatPoint & iterations==1),'.','Color',color);
hold on;
plot(xAxis(isPlotThatPoint & iterations==2),yAxis(isPlotThatPoint & iterations==2),'o','Color',color,'MarkerSize',4);
plot(xAxis(isPlotThatPoint & iterations==3),yAxis(isPlotThatPoint & iterations==3),'d','Color',color,'MarkerSize',4);
hold off;
end

%% Helper function to set section names as x labels
function setSectionNamesAsXLabels(sectionNames)
sectionI = 1:3:length(sectionNames);

xticks(sectionI)
xticklabels(arrayfun(@(x)sprintf('%02d',round(x/3)+1),sectionI,'UniformOutput',false))
xlim([0,length(sectionNames)+1])
xlabel('Slide #')
end