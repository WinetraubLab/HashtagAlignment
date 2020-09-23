function rectifyFineAlignedSections(subjectPath)
%This function takes the fine alinged data tries to correct it to a linear
%function - to reduce noise
% This function will ask user if they would like to update fine tuning
% before doing so.

if ~exist('subjectPath','var')
    subjectPath = s3SubjectPath('58','LGC');
end

% When set to false, will not try to rectify sections that don't have h&e,
% that makes sense since slides with no h&e cannot be fine aligned.
shouldRectifySectionsWithNoHE = false; 

isWriteToCloud = true; % Set to false if you would like to perform dry run that just computes but doesn't write to the cloud

%% Read stack config
stackConfig = awsReadJSON([subjectPath '/Slides/StackConfig.json']);

%% Load stack aligned y position
yStackAligned_mm = ...
    cellfun(@(x)(x(:)'),{stackConfig.stackAlignment.planeDistanceFromOCTOrigin_um},'UniformOutput',false);
yStackAligned_mm = [yStackAligned_mm{:}]'/1e3;
sectionNumber = (1:length(yStackAligned_mm))';

%% Load fine alingned configuration, 
slideConfigs = cell(size(yStackAligned_mm));
slideConfigsJsonPaths = cell(size(yStackAligned_mm));
for i=1:length(slideConfigs)
    nm = stackConfig.sections.names{i};
    
    slideConfigJsonPath = [subjectPath '/Slides/' nm '/SlideConfig.json'];
    slideConfigsJsonPaths{i} = slideConfigJsonPath;
    if awsExist(slideConfigJsonPath,'file')
        slideConfigs{i} = awsReadJSON(slideConfigJsonPath);
    end
end

%% Extract useful data from slide configs
yFineAligned_mm = zeros(size(yStackAligned_mm))*nan;
overallAlignmentQuality = yFineAligned_mm;
yAxisTolerance_um = yFineAligned_mm;
for i=1:length(slideConfigs)
    slideConfig = slideConfigs{i};
    if isempty(slideConfig)
        continue;
    end

    if isfield(slideConfig,'FM') && isfield(slideConfig.FM,'singlePlaneFit_FineAligned')
        yFineAligned_mm(i) = slideConfig.FM.singlePlaneFit_FineAligned.d;
    end
    if isfield(slideConfig,'QAInfo') && ~isempty(slideConfig.QAInfo)
        alignmentQA = slideConfig.QAInfo.AlignmentQuality;
        overallAlignmentQuality(i) = alignmentQA.OverallAlignmentQuality;
        yAxisTolerance_um(i) = alignmentQA.YAxisToleranceMicrons;
    end
    if ~isfield(slideConfig,'histologyImageFilePath')
        yAxisTolerance_um(i) = NaN; %No histology, means no way fine alignment has a reasonable tolerance.
    end
end

% Compute weight for each fine aligned sample
w = exp(overallAlignmentQuality)./yAxisTolerance_um;
w(isnan(w)) = 0;

%% Rectify each iteration
fig1=figure(100);
set(fig1,'units','normalized','outerposition',[0 0 1 1]);

stackIterations = stackConfig.sections.iterations;
yFineAlignedRectified_mm = zeros(size(yFineAligned_mm))*nan;
plotI = 1;
for i = 1:max(stackIterations)
    isInThisIeration = stackIterations == i;
    yStackAligned_umI = yStackAligned_mm(isInThisIeration)*1e3;
    yFineAligned_umI = yFineAligned_mm(isInThisIeration)*1e3;
    sectionNumberI = sectionNumber(isInThisIeration);
    wI = w(isInThisIeration);
    yAxisTolerance_umI = yAxisTolerance_um(isInThisIeration);
    
    if (sum(wI) == 0)
        % Nothing to fit
        continue;
    end
    
    isFineAlignedPlanes = ~isnan(yFineAligned_umI);
    cf = fit(sectionNumberI(isFineAlignedPlanes), ...
        yFineAligned_umI(isFineAlignedPlanes),...
        fittype('poly1'),'Weight',wI(isFineAlignedPlanes));
    p = [cf.p1, cf.p2];
    yFineAlignedRectified_umI = polyval(p,sectionNumberI);
    
    subplot(1,2,plotI);
    plotI = plotI+1;
    plot(sectionNumberI,yStackAligned_umI);
    hold on;
    errorbar(sectionNumberI,yFineAligned_umI,yAxisTolerance_umI, '.');
    plot(sectionNumberI,yFineAlignedRectified_umI);
    hold off;
    ylabel('Plane Distance from OCT Origin [\mum]');
    xlabel('Section #');
    grid on;
    legend(...
        sprintf('Stack Alignment\n(Section Size: %.1f\\mum)',mean(diff(yStackAligned_umI))),...
        'Fine Alignment [User Defined Tolerances]',...
        sprintf('Fine Alignment Poly Fit\n(Bias: %.1f\\mum, Section Size: %.1f\\mum)',...
            mean(yFineAlignedRectified_umI) - mean(yStackAligned_umI),p(1)), ...
        'location','south');
    title(sprintf('%s, Iteration: %d',stackConfig.sampleID,i));
    xlim(sectionNumberI([1 end])' + [-1 1]);
    
    yFineAlignedRectified_mm(isInThisIeration) = yFineAlignedRectified_umI*1e-3;
end

if isWriteToCloud
    answer = questdlg('Should I upload results to the cloud?','Cloud','Yes','No','No');
    if strcmpi(answer,'yes')
       isUpdateCloud = true;
    else
        isUpdateCloud = false;
    end
else
    isUpdateCloud = false;
end

if isUpdateCloud
    path1 = [subjectPath ...
        '/Log/13 Fine Alignment OCT to Histology/RectifyFineAlignedSections_Last.png'];
    path2 = [subjectPath ...
        '/Log/13 Fine Alignment OCT to Histology/RectifyFineAlignedSections_' datestr(now,'yyyymmddHHMM') '.png'];
    awsSaveMatlabFigure(fig1,path1);
    awsCopyFileFolder(path1,path2);
end

%% Update slide config
% Loop over all configs and update
iToValidate = [];
for i=1:length(slideConfigs)
    if isnan(yFineAlignedRectified_mm(i))
        continue; %Nothing to update
    end
    slideConfig = slideConfigs{i};
    if isempty(slideConfig)
        error('Enpty Slide Config should never happen');
        continue; % This should never happen
    end
    if ~isfield(slideConfig,'histologyImageFilePath') && ~shouldRectifySectionsWithNoHE
        %No histology, means no fine alignment, and user asked not to
        %update fine alignment on those.
        continue;
    end 
    
    %% Get information from stack
    iteration = stackConfig.sections.iterations(i);
    n = stackConfig.stackAlignment(iteration).planeNormal; % Normal.s
    pixelSize_um = slideConfig.FM.pixelSize_um; % Bright field pixel size.
    planeDistance = yFineAlignedRectified_mm(i); % Rectified plane distance.
    
    %% Pull the best estimate
    if isfield(slideConfig.FM,'singlePlaneFit_FineAligned')
        % This slide has a single plane fit, use u,v,h, and v_ from that.
        u = slideConfig.FM.singlePlaneFit_FineAligned.u;
        v = slideConfig.FM.singlePlaneFit_FineAligned.v;
        h = slideConfig.FM.singlePlaneFit_FineAligned.h;
        v_ = slideConfig.FM.singlePlaneFit_FineAligned.vTypical;
        
        % Use the most up-to-date scale factor, the one that was fine
        % aligned.
        stackSizeChange_p = slideConfig.FM.singlePlaneFit_FineAligned.sizeChange_precent;
    elseif isfield(slideConfig.FM,'singlePlaneFit')
        % This slide wasn't aligned before, but has single plane fit,
        % before the stack, use that as a bases to rectify to.
        u = slideConfig.FM.singlePlaneFit.u;
        v = slideConfig.FM.singlePlaneFit.v;
        h = slideConfig.FM.singlePlaneFit.h;
        v_ = slideConfig.FM.singlePlaneFit.vTypical;
        
        % Use stack scale factor.
        stackSizeChange_p = 100*(stackConfig.stackAlignment(iteration).scaleFactor-1);    
    else
        % This slide was never aligned before, doesn't even have single plane fit.
        % Provide default values
        
        u = [1 0 0]';
        v = [0 0 1]';
        h = [0 0 0]';
        v_ = NaN;
        
        % Use stack scale factor.
        stackSizeChange_p = 100*(stackConfig.stackAlignment(iteration).scaleFactor-1);
    end
    
    %% Rectify to match with stack, and save
    slideConfig.FM.singlePlaneFit_FineAligned = ...
        spfRealignToStack (u,v,h, ...
        n, planeDistance, stackSizeChange_p, pixelSize_um, v_);
    slideConfig.FM.singlePlaneFit_FineAligned.wasRectified = true;
    slideConfig.FM.singlePlaneFit_FineAligned.notes = sprintf('%s\nwasRectified - did ran rectifyFineAlignedSections?', ...
        slideConfig.FM.singlePlaneFit_FineAligned.notes);
		
	% After rectify, FMOCTAlignment.planeDistanceFromOrigin_mm should be updated as well
	% However, we don't want to do it here since updating planeDistanceFromOrigin_mm may
	% require update of x-y alignment, so just leave it as is. Next time user runs 
	% alignHistology2OCT it will be updated
	% slideConfig.FMOCTAlignment.planeDistanceFromOrigin_mm = slideConfig.FM.singlePlaneFit_FineAligned.d;

    if isUpdateCloud
        awsWriteJSON(slideConfig,slideConfigsJsonPaths{i});
        iToValidate = [iToValidate i];
    end
end

%% Validate proper writing
for i=1:length(iToValidate)
    json = awsReadJSON(slideConfigsJsonPaths{iToValidate(i)});
    if  (~isfield(json.FM,'singlePlaneFit_FineAligned') || ...
        ~isfield(json.FM.singlePlaneFit_FineAligned,'wasRectified') || ...
        ~json.FM.singlePlaneFit_FineAligned.wasRectified)
        error('Slide %s was not updated',slideConfigsJsonPaths{iToValidate(i)});
    end
end