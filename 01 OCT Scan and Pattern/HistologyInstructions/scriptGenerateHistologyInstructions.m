%This script generates histology instructions

%% Inputs
subjectFolder = s3SubjectPath('01');
yourName = 'MyUser';

iteration = 1;
isCutOnDotSide = 1; %1-true, -1 - oposite side

%Distance to OCT origin:
%In iteration #1 - distance from full face to origin
%In following iterations - distance from current position to origin
distanceToOCTOrigin_um = 1000; %um

isUpdateAWS = false;

%% Define optimal cuting scheme
%iteration #1 is the first itration, #2 are all that follow

%Position of slides at each iteration
whereToCut_um_Iteration1 = (0:(2*3-1))*30; %2 slide, 3 sections
whereToCut_um_Iteration2 = (0:(5*3-1))*30; %5 slide, 3 sections

%Position of the center slide for each iteration compared to OCT origin
iteration1CenterOffset = -250; %um, this iteration is undershooting the center
iteration2CenterOffset = 0;    %um, this iteration should be centered around origin

%% Jenkins
if exist('subjectFolder_','var')
    subjectFolder = subjectFolder_;
    yourName = yourName_;
    iteration = iteration_;
    distanceToOCTOrigin_um = distanceToOCTOrigin_um_;
    isUpdateAWS = true;
end
if exist('isCutOnDotSide_','var')
    isCutOnDotSide = isCutOnDotSide_;
end

%% Decide where to cut
whereToCut_um_Iteration1 = whereToCut_um_Iteration1-mean(whereToCut_um_Iteration1) + iteration1CenterOffset;
whereToCut_um_Iteration2 = whereToCut_um_Iteration2-mean(whereToCut_um_Iteration2) + iteration2CenterOffset;

if (iteration == 1)
    whereTocut = whereToCut_um_Iteration1;
else
    whereTocut = whereToCut_um_Iteration2;
end
whereTocut = whereTocut + distanceToOCTOrigin_um;

if (min(whereTocut) < 0)
    %Cannot cut in the past, advance
    whereTocut = whereTocut-min(whereTocut);
end

%% Setup paths
[~,subjectName] = fileparts([subjectFolder(1:(end-1)) '.a']);
jsonPath = awsModifyPathForCompetability([subjectFolder '/Slides/HistologyInstructions.json']);
logPath = awsModifyPathForCompetability([subjectFolder '/Log/01 OCT Scan and Pattern/']);

%If this is not the first iteration, load JSON to tell him
if (iteration > 1)
    json = awsReadJSON(jsonPath);
    in2 = json;
else
    isJsonExist = false;
    try
        json = awsReadJSON(jsonPath);
        isJsonExist = true;
    catch
        %Do nothing
    end
    if (isJsonExist)
        error('You say its iteration #1, but json path exists, is that ok? %s',jsonPath);
    end
    in2 = isCutOnDotSide;
end

%% Check iteration #2 was not set before, if it did, override it
if (iteration > 2)
    warning('Iteration #2 exists, deleting it before adding iteration #2');
    in2.iterationDates = in2.iterationDates(1);
    in2.iterationOperators = in2.iterationOperators(1);
    ii = in2.sectionIteration>=2;
    in2.sectionIteration(ii)= [];
    in2.sectionDepthsRequested_um(ii) = [];
    in2.sectionName(ii) = [];
end

%% Build Histology Instructions
if (iteration == 1)
    tmp = distanceToOCTOrigin_um; %Get distance to origin from user
else
    tmp = []; %In followup iterations distance to origin is calculated by analyzeAlignmentStack.m, don't override their analysis
end
HI = hiGenerateHistologyInstructions(whereTocut,in2,yourName,now,subjectName,tmp);

%Upload istructions
if (isUpdateAWS)
    awsWriteJSON(HI,jsonPath);
end

%Generate Instructions, in the log put all instructions, locally just this
%iteration's
if (isUpdateAWS)
    hiGenerateInstructionsFile(jsonPath,[logPath 'HistologyInstructions.pdf']);
    hiGenerateInstructionsFile(jsonPath,'HistologyInstructions.pdf',iteration);
else
    hiGenerateInstructionsFile(HI,'HistologyInstructions.pdf',iteration);
end

