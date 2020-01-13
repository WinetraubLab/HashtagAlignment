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
jsonPath = awsModifyPathForCompetability([subjectFolder '/Slides/StackConfig.json']);
logPath = awsModifyPathForCompetability([subjectFolder '/Log/01 OCT Scan and Pattern/']);

%If this is not the first iteration, load JSON to tell him
if (iteration > 1)
    stackConfig = awsReadJSON(jsonPath);
    
    % Check iteration #2 was not set before, if it did, override it
    if (iteration > 2)
        warning('Iteration #2 exists, deleting it before adding iteration #2');
        stackConfig = scDeleteIterationsFromStackConfig(stackConfig, ...
            2:length(stackConfig.histologyInstructions.iterations));
    end
    
    inputs = {'appendToSC', stackConfig};
else
    
    if awsExist(jsonPath,'file')
        error('You say its iteration #1, but json path exists, is that ok? %s',jsonPath);
    end 
    
    inputs = {'startCuttingAtDotSide', isCutOnDotSide};
end

%% Build Histology Instructions
inputs = [inputs {...
    'sampleID', subjectName, ...
    'iterationNumber', iteration, ...
    'sectionDepthsRequested_um', whereTocut, ...
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

