function submitStatusReportToGoogle(st)
% st can be status report structure or path

%% Constants
sendToHistologyDistance_um = 550;

%% Input checks
if ~exist('st','var')
    st = [s3SubjectPath('','LG') '0LibraryStatistics/' '/StatusReportBySection.json'];
end

if ischar(st)
    st = awsReadJSON(st);
end

%% For debug purposes, find a specific slide that we would like to focus on
dSubject = 'LG-42';
dSlideSection = 'Slide05_Section03';
dI = cellfun(@(x)(contains(x,dSubject) && contains(x,dSlideSection)),st.sectionPahts); 
if ~any(dI) 
    dI = -1;
else
    dI = find(dI); % dI will contain the right section we are looking for. Set a breakpoint and i=dI and it should work, including loading the one off files needed.
end

%% Generate google update (slides sheet)
gs = [];
repStrings = {};
isRunOnce = true;
fprintf('Uploading %d sections to google, wait for 20 stars ... [ ',length(st.subjectNames)); tic
for i=1:length(st.subjectNames)
    if mod(i,round(length(st.subjectNames)/20)) == 0
        fprintf('* ');
    end
    
    clear item;
    item.Table = 'SlidesRunsheet';
    item.FullSlideName = sprintf('%s-%s',st.subjectNames{i},st.sectionNames{i}); % Search for column
    repStrings(end+1,:) = {'FullSlideName','Full Slide Name'};
    
    sectionPath = st.sectionPahts{i};
    subjectPath = st.subjectPahts{i};
        
    %% Answer questions - Coarse alignment
    
    % is OCT Volume Processed
    if st.isOCTVolumeProcessed(i)
        url = awsGenerateTemporarySharableLink([subjectPath '/OCTVolumes/VolumeScanAbs/y0500.tif']);
        item.WasOCTVolumeProcessed__auto_ = sprintf('=HYPERLINK("%s","Yes")',url);
    else
        item.WasOCTVolumeProcessed__auto_ = 'No';
    end
    repStrings(end+1,:) = {'WasOCTVolumeProcessed__auto_','Was OCT Volume Processed? [auto]'};
    
    % isFluorescenceImageUploaded
    if st.isFluorescenceImageUploaded(i)
        url = awsGenerateTemporarySharableLink([sectionPath '/FM_PhotobleachedLinesImage.tif']);
        item.FluorescenceImageUploaded__auto_ = sprintf('=HYPERLINK("%s","Yes")',url);
    else
        item.FluorescenceImageUploaded__auto_ = 'No';
    end
    repStrings(end+1,:) = {'FluorescenceImageUploaded__auto_','Fluorescence Image Uploaded? [auto]'};
    
    % Marked Lines
    if st.areFiducialLinesMarked(i)
        url = awsGenerateTemporarySharableLink(sprintf(...
            '%s/Log/03 Fluorescence Preprocess/%s.png',...
            subjectPath,st.sectionNames{i}));
        item.NumberofMarkedLines_auto_ = sprintf('=HYPERLINK("%s",%d)',url,st.nOfFiducialLinesMarked(i));
    else
        item.NumberofMarkedLines_auto_ = 'No Marked Lines'; 
    end
    repStrings(end+1,:) = {'NumberofMarkedLines_auto_','Number of Marked Lines [auto]'};
    
    % Size Change
    if st.areFiducialLinesMarked(i) && ~isnan(st.sectionDistanceFromOCTOrigin2SectionAlignment_um(i)) % Lines marked and section alignment ran
        url = '';
        try
            url = awsGenerateTemporarySharableLink(sprintf(...
                '%s/Log/11 Align OCT to Flourecence Imaging/%s_SlideAlignment.png',...
                subjectPath,st.sectionNames{i}));
        catch
            % Do nothing, sometimes this url doesnt exist
        end
        txt = sprintf('%.1f',st.sectionSizeChange_percent(i));
        txt = strrep(txt,'NaN','"NaN"'); %If nan add ""
        item.SizeChange____auto_ = sprintf('=HYPERLINK("%s",%s)',url,txt);
    else
        item.SizeChange____auto_ = 'N/A'; 
    end
    repStrings(end+1,:) = {'SizeChange____auto_','Size Change [%] [auto]'};
    
    % Proper Alignment With Stack
    if st.isRanStackAlignment(i)
        if st.isSectionPartOfAlingedStack(i)
            if  st.wasSectionUsedInComputingStackAlignment(i)
                txt1 = 'Yes';
            else
                txt1 = 'Maybe';
            end
            txt2 = sprintf('%.0f',abs(st.sectionDistanceFromOCTOrigin3StackAlignment_um(i)));
        else
            txt1 = 'No';
            txt2 = sprintf('%.0f',abs(st.sectionDistanceFromOCTOrigin2SectionAlignment_um(i)));
        end
        txt2 = strrep(txt2,'NaN','"NaN"'); %If nan add ""
        url = awsGenerateTemporarySharableLink(sprintf(...
            '%s/Log/11 Align OCT to Flourecence Imaging/StackAlignmentFigure1.png',...
            subjectPath));
        item.ProperAlignmentWithStack__auto_ = sprintf('=HYPERLINK("%s","%s")',url,txt1);
        url = awsGenerateTemporarySharableLink(sprintf(...
            '%s/Log/11 Align OCT to Flourecence Imaging/StackAlignmentFigure2.png',...
            subjectPath));
        item.DistanceFromOriginC_um__auto_ = sprintf('=HYPERLINK("%s",%s)',url,txt2); 
    else
        item.ProperAlignmentWithStack__auto_ = 'Run Stack Alignment';
        item.DistanceFromOriginC_um__auto_ = 'N/A';
    end
    repStrings(end+1,:) = {'ProperAlignmentWithStack__auto_','Proper Alignment With Stack? [auto]'};
    repStrings(end+1,:) = {'DistanceFromOriginC_um__auto_','Distance From Origin C [um] [auto]'};
    
    % Was resliced?
    if st.wasResliceOCTVolumeRun(i)
        stackVolumePath = sprintf('%s/OCTVolumes/StackVolume_Iteration%d/',...
            subjectPath, st.iteration(i));
        %n = length(awsls(stackVolumePath));
        n = 400; % Conservative number, to avoid awsls every time.
        
        url = awsGenerateTemporarySharableLink(sprintf('%s/y%04d.tif',...
            stackVolumePath, round(n/2)));
        item.OCTResliced__auto_ = sprintf('=HYPERLINK("%s","Yes")',url);
    else
        item.OCTResliced__auto_ = 'No';
    end
    repStrings(end+1,:) = {'OCTResliced__auto_','OCT Resliced? [auto]'};
    
    %% Make a recomendation, should we send slide to histology?
    if st.isRanStackAlignment(i)
        fineAlignmentCanComplete = true;
        if(abs(st.sectionDistanceFromOCTOrigin3StackAlignment_um(i))<sendToHistologyDistance_um)
            item.SendtoH_E_Recommend_auto_ = 'Yes'; 
        else
            item.SendtoH_E_Recommend_auto_ = 'No';
        end
    else
        fineAlignmentCanComplete = false;
        item.SendtoH_E_Recommend_auto_ = 'N/A';
    end
    repStrings(end+1,:) = {'SendtoH_E_Recommend_auto_','Send to H&E? Recommend [auto]'};

    %% Fine Alignment
    
    % Histology Uploaded
    if (st.isHistologyImageUploaded(i))
        url = awsGenerateTemporarySharableLink([sectionPath '/FM_HAndE.tif']);
        item.H_EUploaded__auto_ = sprintf('=HYPERLINK("%s","Yes")',url);
    else
        item.H_EUploaded__auto_ = 'No'; 
        fineAlignmentCanComplete = false;
    end
    repStrings(end+1,:) = {'H_EUploaded__auto_','H&E Uploaded? [auto]'};
    
    % Registered to Fluorescence image
    if st.isCompletedHistologyFluorescenceImageRegistration(i)
        url = awsGenerateTemporarySharableLink(sprintf(...
            '%s/Log/04 Histology Preprocess/%s_HistFMRegistration.png',...
            subjectPath,st.sectionNames{i}));
        if st.wasHistologyFluorescenceImageRegistrationSuccessful(i)
            item.H_ERegisteredtoBrightfield__auto_ = sprintf('=HYPERLINK("%s","Yes")',url);
        else
            item.H_ERegisteredtoBrightfield__auto_ = sprintf('=HYPERLINK("%s","Yes, Registration Failed")',url);
        end
    else
        if (fineAlignmentCanComplete)
            item.H_ERegisteredtoBrightfield__auto_ = 'No'; 
        else
            item.H_ERegisteredtoBrightfield__auto_ = 'N/A';
            fineAlignmentCanComplete = false;
        end
    end
    repStrings(end+1,:) = {'H_ERegisteredtoBrightfield__auto_','H&E Registered to Brightfield? [auto]'};
    
    % Is fine alignment done?
    if st.isCompletedOCTHistologyFineAlignment(i)
        url = awsGenerateTemporarySharableLink(sprintf(...
            '%s/Log/13 Fine Alignment OCT to Histology/%s.png',...
            subjectPath,st.sectionNames{i}));
        item.WasFineAlignmentRan__auto_ = sprintf('=HYPERLINK("%s","Yes")',url);
    else
        item.WasFineAlignmentRan__auto_ = "No";
    end
    repStrings(end+1,:) = {'WasFineAlignmentRan__auto_','Was Fine Alignment Ran? [auto]'};
    
    % Fine alignment complete & rectified
    if st.wasRectified(i)
        url = awsGenerateTemporarySharableLink(sprintf(...
            '%s/Log/13 Fine Alignment OCT to Histology/RectifyFineAlignedSections_Last.png',...
            subjectPath));
        if st.didUserFineTuneAlignmentAfterRectified(i)
            item.WasRectified__auto_ = sprintf('=HYPERLINK("%s","Yes")',url);    
        else
            item.WasRectified__auto_ = sprintf('=HYPERLINK("%s","Yes, but fine tune is required. Please run fine alignment. Check X-Z position, rotation and save again")',url);    
        end
    else
        item.WasRectified__auto_ = 'No';
    end
    repStrings(end+1,:) = {'WasRectified__auto_','Was Rectified? [auto]'};
    
    % Distance from origin after fine aligned
    if st.isCompletedOCTHistologyFineAlignment(i)
        txt = sprintf('%.0f',abs(st.sectionDistanceFromOCTOrigin4FineAlignment_um(i)));
        url = awsGenerateTemporarySharableLink(sprintf(...
            '%s/Log/13 Fine Alignment OCT to Histology/%s.png',...
            subjectPath,st.sectionNames{i}));
        item.DistanceFromOriginF_um__auto_ = sprintf('=HYPERLINK("%s",%s)',url,txt);
    else
        if (fineAlignmentCanComplete)
            item.DistanceFromOriginF_um__auto_ = 'Not Ran';
            fineAlignmentCanComplete = false;
        else
            item.DistanceFromOriginF_um__auto_ = 'N/A';
        end
    end
    repStrings(end+1,:) = {'DistanceFromOriginF_um__auto_','Distance From Origin F [um] [auto]'};
    
    %% Quality Control
    
    % Did Quality Control Done
    if st.isQualityControlMaskGenerated(i)
        url = awsGenerateTemporarySharableLink(sprintf(...
            '%s/Log/14 Quality Control and Post Processing/%s.png',...
            subjectPath,st.sectionNames{i}));
        item.IsQualityControlDone__auto_ = sprintf('=HYPERLINK("%s","%s")',url,"Yes");
        item.AreaofQualityData_mmsq__auto_ = sprintf('%.3f',st.areaOfQualityData_mm2(i));
    else
        if (fineAlignmentCanComplete)
            item.IsQualityControlDone__auto_ = 'Quality Control Mask Not Generated or No Fine Tune Alignment After Rectified';
            fineAlignmentCanComplete = false;
        else
            item.IsQualityControlDone__auto_ = 'N/A';
        end
        item.AreaofQualityData_mmsq__auto_ = 'N/A';
    end
    repStrings(end+1,:) = {'IsQualityControlDone__auto_','Is Quality Control Done? [auto]'};
    repStrings(end+1,:) = {'AreaofQualityData_mmsq__auto_','Area of Quality Data [mm sq] [auto]'};
    
    if fineAlignmentCanComplete
        % Make a urlt oslide config
        slideConfigUrl = awsGenerateTemporarySharableLink(sprintf(...
            '%s/SlideConfig.json', st.sectionPahts{i}));
    end
    
    if isnan(st.isOCTImageQualityGood(i)) || ~fineAlignmentCanComplete
        item.OCTImageQuality_auto_ = 'N/A';
    else
        if (st.isOCTImageQualityGood(i))
            txt = 'Good';
        else
            txt = 'Poor';
        end
        item.OCTImageQuality_auto_ = sprintf('=HYPERLINK("%s","%s")',slideConfigUrl,txt);
    end
    repStrings(end+1,:) = {'OCTImageQuality_auto_','OCT Image Quality [auto]'};
    
    if isnan(st.alignmentQuality(i)) || ~fineAlignmentCanComplete
        item.AlignmentQuality_auto_ = 'N/A';
    else
        if st.alignmentQuality(i) >= 2.5
            txt = 'Good';
        elseif st.alignmentQuality(i) > 1.5 % 1.5 is the threshold for isUsableInML
            txt = 'Fair';
        else
            txt = 'Poor';
        end
        item.AlignmentQuality_auto_ = sprintf('=HYPERLINK("%s","%s")',slideConfigUrl,txt);
    end
    repStrings(end+1,:) = {'AlignmentQuality_auto_','Alignment Quality [auto]'};

    %% Is usable - decide according to quality
    if st.isUsableInML(i)
        item.IsUseable__Auto_ = 'Yes';
    else
        item.IsUseable__Auto_ = 'No';
    end
    repStrings(end+1,:) = {'IsUseable__Auto_','Is Useable? [Auto]'};
    
    %% Upload to google  
    if isRunOnce
        repStrings1 = repStrings;
        isRunOnce = false;
    end
    repStrings = {};
    gs.Items(i) = item;
    submitItemToGoogle(item,repStrings1);
end
fprintf(']. Done, took %.0f minutes\n',toc()/60);

end
%% Helper function to submit stuff to google
function submitItemToGoogle(item,repStrings)
% Post process string to match columns in google
gs.Items = [];
if false
    % Load specific fields
    fn = fieldnames(item);
    for i=[1 2 length(fn)] %1:length(fn)
        gs.Items.(fn{i}) = item.(fn{i});
    end
else
    % Load all fields
    gs.Items = item;
end
gsStr = jsonencode(gs);

% Make sure items is an array, because this is what google is expecting
gsStr = strrep(gsStr,'{"Items":{','{"Items":[{');
gsStr((end-1):(end+1)) = '}]}';

% Replace naming
for i=1:size(repStrings,1)
    gsStr = strrep(gsStr,repStrings{i,1},repStrings{i,2});
end

url = 'https://script.google.com/macros/s/AKfycbxOeKO4zLt-rlFyLPCbwf9uItBeQeBPQzJtPxctvMe511jOMbU/exec';
try
    options = weboptions('Timeout', 30);
    data = webread(url,'jsonTxt',gsStr,options);
catch ME
    disp(ME)
    ME.stack
end

end
