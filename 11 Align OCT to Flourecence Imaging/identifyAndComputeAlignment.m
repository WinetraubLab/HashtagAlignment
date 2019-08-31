%This function identifies lines and compute basic alignment (single plane)

%% Inputs
slideFilepath =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01/Slides/Slide02_Section02/SlideConfig.json';

rewriteMode = true; %Don't re write information

%% Jenkins?
if exist('slideFilepath_','var')
    slideFilepath = slideFilepath_;
end
awsSetCredentials(1);

%% Extract Slide Folder
disp([datestr(now) ' Loading JSON']);
slideFolder = awsModifyPathForCompetability([fileparts(slideFilepath) '/']);
ds = fileDatastore(slideFolder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
slideJsonFilePath = ds.Files{1};
slideJson = ds.read();

octVolumeFolder = awsModifyPathForCompetability([slideFolder '../../OCTVolumes/']);
ds = fileDatastore(octVolumeFolder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
octVolumeJsonFilePath = ds.Files{1};
octVolumeJson = ds.read();

%% Load Flourecent image
disp([datestr(now) ' Loading Flourecent Image']);
ds = fileDatastore(awsModifyPathForCompetability([slideFolder slideJson.photobleachedLinesImagePath]),'ReadFcn',@imread);
histologyFluorescenceIm = ds.read();

%% Identify Lines
disp([datestr(now) ' Identify Lines']);

f = slideJson.FM.fiducialLines;
f = fdlnSortLines(f); %Sort lines such that they are organized by position, left to right
fOrig = f;

if ~contains([f.group],'1') && ~rewriteMode
    %Identification already happend, skip
    [slideJson,isIdentifySuccssful] = identifyLinesAndAlignSlide(slideJson,octVolumeJson,'None');
else
    [slideJson1,isIdentifySuccssful] = identifyLinesAndAlignSlide(slideJson,octVolumeJson,'ByLinesRatio');
    
    if (isIdentifySuccssful)
        slideJson = slideJson1;
    end
end    

%% Plot
if (isidentifySuccssful)
    plotSignlePlane(slideJson.FM.singlePlaneFit,slideJson.FM.fiducialLines,histologyFluorescenceIm,octVolumeJson);
else
    plotSignlePlane(NaN,slideJson.FM.fiducialLines,histologyFluorescenceIm,octVolumeJson);
end

%% Prompt user, would they like to update before we save?
if (rewriteMode)
	button = questdlg('Would you like to manually override line identification?','Q','Yes','No','No');
    if (strcmp(button,'Yes'))
        [slideJson,isIdentifySuccssful] = identifyLinesAndAlignSlide(slideJson,octVolumeJson,'Manual');
        plotSignlePlane(slideJson.FM.singlePlaneFit,slideJson.FM.fiducialLines,histologyFluorescenceIm,octVolumeJson);
    end
end

%% Save to JSON & figure
if (rewriteMode)
    disp([datestr(now) ' Saving Updated JSON & Figure']);
    awsWriteJSON(slideJson,slideJsonFilePath);
    
    if exist('SlideAlignment.png','file')
        if (awsIsAWSPath(slideJsonFilePath))
            %Upload to AWS
            awsCopyFileFolder('SlideAlignment.png',[fileparts(slideJsonFilePath) '/SlideAlignment.png']);
        else
            copyfile('SlideAlignment.png',[fileparts(slideJsonFilePath) '\SlideAlignment.png']);
        end   
    end
end