%This function identifies lines and compute basic alignment (single plane)

%% Inputs

subjectFolder = s3SubjectPath('14','LC');
slideName = 'Slide04_Section02'; %Leve empty for loading of all slides, otherwise specify 'Slide01_Section01'

% How to identify the lines. Can be: 
% - 'ByLinesRatio' - use lines ratio 
% - 'ByStack' - to compute alignment according to what best fits the stack
% - 'Manual' - user inputs
% - 'None' - keep as is 
lineIdentifyMethod = 'None'; 

%Would you like to upload updated information to the cloud (JSON update)
rewriteMode = false; 

%If not empty, will write the overview files to Log Folder
logFolder = awsModifyPathForCompetability([subjectFolder '/Log/11 Align OCT to Flourecence Imaging/']);
%logFolder = [];

%% Find all JSONS in folder
awsSetCredentials(1);

disp([datestr(now) ' Loading JSON(s)']);
if ~exist('subjectFolderUsed','var') || ~strcmp(subjectFolder,subjectFolderUsed)
    subjectFolderUsed = subjectFolder;
    %First time, load all JSONs
    % Any fileDatastore request to AWS S3 is limited to 1000 files in 
    % MATLAB 2021a. Due to this bug, we have replaced all calls to 
    % fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
    % 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
    ds = imageDatastore(subjectFolder,'ReadFcn',@awsReadJSON,'FileExtensions','.json','IncludeSubfolders',true);
    jsons = ds.readall();
    jsonsFilePaths = ds.Files;
end

octJsonI = [find(cellfun(@(x)contains(x,'\ScanConfig.json'),jsonsFilePaths)); find(cellfun(@(x)contains(x,'/ScanConfig.json'),jsonsFilePaths))];
octVolumeJsonFilePath = jsonsFilePaths{octJsonI};
octVolumeJson = jsons{octJsonI};

slideJsonsI = find(cellfun(@(x)contains(x,'SlideConfig.json') & contains(x,slideName),jsonsFilePaths));
slideJsonFilePaths = jsonsFilePaths(slideJsonsI);
slideJsons = [jsons{slideJsonsI}];

%Compute Stack (in case we need it for by stack alignment)
slideJsonsI2 = find(cellfun(@(x)contains(x,'SlideConfig.json'),jsonsFilePaths));
SlidesJsonsStack = [jsons{slideJsonsI2}]; %For the entire subject

%% Load Enface view if avilable 
try
    % Any fileDatastore request to AWS S3 is limited to 1000 files in 
    % MATLAB 2021a. Due to this bug, we have replaced all calls to 
    % fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
    % 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
    ds = imageDatastore([subjectFolder '/OCTVolumes/OverviewScanAbs_Enface.tif'],'ReadFcn',@yOCTFromTif,'FileExtensions','.tif','IncludeSubfolders',true);
    enfaceView = ds.read();
catch
    enfaceView = [];
end

%% Loop over all slides
for slideI=1:length(slideJsons)
    
%% Read JSON & Load Flourecent Image
slideJson = slideJsons(slideI);
slideJsonFilePath = slideJsonFilePaths{slideI};
slideFolder = [fileparts(slideJsonFilePath) '/'];
[~,slideName] = fileparts([slideFolder(1:(end-1)) '.a']);
slideName = strrep(slideName,'_',' ');

if ~isfield(slideJson.FM,'fiducialLines')
    fprintf('%s doesn''t have fiducialLines marked. Skipping\n',slideJsonFilePath);
    continue;
end

%Load Flourecent image
disp([datestr(now) ' Loading Flourecent Image']);
% Any fileDatastore request to AWS S3 is limited to 1000 files in 
% MATLAB 2021a. Due to this bug, we have replaced all calls to 
% fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
% 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
ds = imageDatastore(awsModifyPathForCompetability([slideFolder slideJson.photobleachedLinesImagePath]),'ReadFcn',@imread);
histologyFluorescenceIm = ds.read();

%% Align and plot
try
[slideJson1,isIdentifySuccssful] = identifyLinesAndAlignSlide(slideJson,octVolumeJson,lineIdentifyMethod,SlidesJsonsStack);
catch Me
    disp(Me.message)
    for i=1:length(Me.stack)
        Me.stack(i)
    end
    isIdentifySuccssful = false;
end

if (isIdentifySuccssful)
    plotSignlePlane(slideJson1.FM.singlePlaneFit,slideJson1.FM.fiducialLines,histologyFluorescenceIm,octVolumeJson,true);
    title(slideName);
    pause(0.01);
else
    disp('Identification Failed');
end

if ~isempty(enfaceView)
    figure;
    spfPlotTopView( ...
        slideJson1.FM.singlePlaneFit,octVolumeJson.photobleach.hLinePositions,octVolumeJson.photobleach.vLinePositions, ...
        'lineLength',octVolumeJson.photobleach.lineLength, ...
        'theDot',[octVolumeJson.theDotX; octVolumeJson.theDotY],...
        'enfaceViewImage',enfaceView, ...
        'enfaceViewImageXLim', [min(octVolumeJson.overview.xCenters) max(octVolumeJson.overview.xCenters)] + octVolumeJson.overview.range*[-1/2 1/2],...
        'enfaceViewImageYLim', [min(octVolumeJson.overview.yCenters) max(octVolumeJson.overview.yCenters)] + octVolumeJson.overview.range*[-1/2 1/2] ...
        );
    colormap bone
end
%% Save to JSON & figure
if (isIdentifySuccssful && rewriteMode)
    slideJson = slideJson1;

    disp([datestr(now) ' Saving Updated JSON & Figure']);
    awsWriteJSON(slideJson,slideJsonFilePath);
    
    if exist('SlideAlignment.png','file') && ~isempty(logFolder)
        %Upload / Copy
        awsCopyFileFolder('SlideAlignment.png',[logFolder '/' slideName '_SlideAlignment.png']);
    end
end

end %For
disp([datestr(now) ' Done']);