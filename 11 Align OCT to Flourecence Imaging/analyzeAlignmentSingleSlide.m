%This function identifies lines and compute basic alignment (single plane)

%% Inputs

subjectFolder =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LC/LC-01/';
slideName = 'Slide01_Section01'; %Leve empty for loading of all slides, otherwise specify 'Slide01_Section01'

% How to identify the lines. Can be: 
% - 'ByLinesRatio' - use lines ratio 
% - 'ByStack' - to compute alignment according to what best fits the stack
% - 'Manual' - user inputs
% - 'None' - keep as is 
lineIdentifyMethod = 'ByStack'; 

%Would you like to upload updated information to the cloud (JSON update)
rewriteMode = true; 

%% Find all JSONS in folder
awsSetCredentials(1);

disp([datestr(now) ' Loading JSON(s)']);
if ~exist('subjectFolderUsed','var') || ~strcmp(subjectFolder,subjectFolderUsed)
    subjectFolderUsed = subjectFolder;
    %First time, load all JSONs
    ds = fileDatastore(subjectFolder,'ReadFcn',@awsReadJSON,'FileExtensions','.json','IncludeSubfolders',true);
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
ds = fileDatastore(awsModifyPathForCompetability([slideFolder slideJson.photobleachedLinesImagePath]),'ReadFcn',@imread);
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
    plotSignlePlane(slideJson1.FM.singlePlaneFit,slideJson1.FM.fiducialLines,histologyFluorescenceIm,octVolumeJson);
    title(slideName);
    pause(0.01);
else
    disp('Identification Failed');
end

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

end %For
disp([datestr(now) ' Done']);