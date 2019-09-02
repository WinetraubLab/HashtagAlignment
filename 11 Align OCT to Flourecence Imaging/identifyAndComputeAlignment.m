%This function identifies lines and compute basic alignment (single plane)

%% Inputs
slideFilepath =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/DoubleHashtag/Slides/Slide04_Section12/';

rewriteMode = true; %Don't re write information
lineIdentifyMethod = 'ByLinesRatio'; % Can be: 'ByLinesRatio' or 'Manual'


%% Extract Slide Folder
awsSetCredentials(1);
disp([datestr(now) ' Loading JSON']);
slideFolder = awsModifyPathForCompetability([fileparts(slideFilepath) '/']);
ds = fileDatastore(slideFolder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
slideJsonFilePath = ds.Files{1};
slideJson = ds.read();

if ~isfield(slideJson.FM,'fiducialLines')
    error('%s doesn''t have fiducialLines marked.',slideJsonFilePath);
end

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

[slideJson1,isIdentifySuccssful] = identifyLinesAndAlignSlide(slideJson,octVolumeJson,lineIdentifyMethod);

plotSignlePlane(slideJson1.FM.singlePlaneFit,slideJson1.FM.fiducialLines,histologyFluorescenceIm,octVolumeJson);

%% Save to JSON & figure
if (isIdentifySuccssful && rewriteMode)
    slideJson = slideJson1;

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