%This script generates histology instructions from text files

%% Inputs
subjectFolder = s3SubjectPath('01');

%% Do work
awsSetCredentials(1);

logPath = awsModifyPathForCompetability([subjectFolder 'Log/01 OCT Scan and Pattern/']);
jsonPath = awsModifyPathForCompetability([subjectFolder 'Slides/HistologyInstructions.json']);

%Read text from datastore
ds = fileDatastore([logPath 'histoInstructions.txt'],'ReadFcn',@fileread);
HIText = ds.read;

%Convert text to HI structure
HI = hiGenerateHistologyInstructions(HIText);

%Save it back to subject
awsWriteJSON(HI,jsonPath);
hiGenerateInstructionsFile(jsonPath,[logPath 'HistologyInstructions.pdf']);

HIText
hiGenerateInstructionsFile(jsonPath,['HistologyInstructions.pdf']);

%Delete prev text file
awsRmFile([logPath 'histoInstructions.txt']);