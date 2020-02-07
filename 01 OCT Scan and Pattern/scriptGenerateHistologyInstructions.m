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
isOverrideExistingInstructions = false; %If instructions exist for iteration already, don't override them - provide an error.

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
    isOverrideExistingInstructions = isOverrideExistingInstructions_;
    isUpdateAWS = true;
end
if exist('isCutOnDotSide_','var')
    isCutOnDotSide = isCutOnDotSide_;
end
if exist('numberOfSlidesToCut_','var') && ~isnan(numberOfSlidesToCut_)
    numberOfSlidesToCut = numberOfSlidesToCut_;
else
    % Select number of sections based on iteration
    if (iteration == 1)
        numberOfSlidesToCut = 2;
    else
        numberOfSlidesToCut = 5;
    end
end

%% Decide where to cut
whereToCut_um = (0:(numberOfSlidesToCut*3-1))*30;
whereToCut_um = whereToCut_um - mean(whereToCut_um);
if (iteration == 1)
    whereToCut_um = whereToCut_um + iteration1CenterOffset;
else
    whereToCut_um = whereToCut_um + iteration2CenterOffset;
end
whereToCut_um = whereToCut_um + distanceToOCTOrigin_um;

if (min(whereToCut_um) < 0)
    %Cannot cut in the past, advance
    whereToCut_um = whereToCut_um-min(whereToCut_um);
end

%% Setup paths
subjectName = s3GetSubjectName(subjectFolder);
jsonPath = awsModifyPathForCompetability([subjectFolder '/Slides/StackConfig.json']);
logPath = awsModifyPathForCompetability([subjectFolder '/Log/01 OCT Scan and Pattern/']);

%% Check that iteration been added is the correct one
isStackConfigFileExist = awsExist(jsonPath,'file');
isIterationAlreadyExist = false;

if (iteration == 1 && isStackConfigFileExist)
    isIterationAlreadyExist = true;
elseif iteration > 1
    stackConfig = awsReadJSON(jsonPath);    
    isIterationAlreadyExist = any(stackConfig.sections.iterations == iteration);
end

if isIterationAlreadyExist && ~isOverrideExistingInstructions
    error('User wanted to update iteration %d but it already exist. Please set isOverrideExistingInstructions to true to allow override.',iteration);
elseif isIterationAlreadyExist && isOverrideExistingInstructions
    if iteration == 1
        % Start over instructions
        inputs = {'startCuttingAtDotSide', isCutOnDotSide};
    elseif iteration > 1
        % Delete last iteration.
        stackConfig = scDeleteIterationsFromStackConfig(stackConfig, ...
            iteration);
        inputs = {'appendToSC', stackConfig};
    end
else % Iteration doesn't exist
    if iteration == 1
        inputs = {'startCuttingAtDotSide', isCutOnDotSide};
    elseif iteration > 1
        inputs = {'appendToSC', stackConfig};
    end
end

%% Build Histology Instructions
inputs = [inputs {...
    'sampleID', subjectName, ...
    'iterationNumber', iteration, ...
    'sectionDepthsRequested_um', whereToCut_um, ...
    'estimatedDistanceFromFullFaceToOCTOrigin_um', distanceToOCTOrigin_um,...
    'operator', yourName, ...
    'date', now, ...
    }];

stackConfig = scGenerateStackConfig(inputs);

%Upload istructions
if (isUpdateAWS)
    awsWriteJSON(stackConfig,jsonPath);
end

%Generate Instructions, in the log put all instructions, locally just this
%iteration's
if (isUpdateAWS)
    scGenerateHistologyInstructionsFile(jsonPath,[logPath 'HistologyInstructions.pdf']);
    scGenerateHistologyInstructionsFile(jsonPath,'HistologyInstructions.pdf',iteration);
else
    scGenerateHistologyInstructionsFile(stackConfig,'HistologyInstructions.pdf',iteration);
end

