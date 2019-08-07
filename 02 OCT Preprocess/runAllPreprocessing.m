%This script runs all preprocessing sequentially

%% Inputs
SubjectFolderIn = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-00/';
SubjectFolderOut = SubjectFolderIn; %Where to save folder to

%% Setup environment
if (isRunningOnJenkins()) %Get inputs from Jenkins
    SubjectFolderIn = SubjectFolderIn_;
    SubjectFolderOut = SubjectFolderOut_;
end

if (awsIsAWSPath(SubjectFolderIn))
    inputFolderAWS = true;
else
    inputFolderAWS = false;
end

if (awsIsAWSPath(SubjectFolderOut))
    outputFolderAWS = true;
else
    outputFolderAWS = false;
end

runninAll = true;
OCTVolumesFolder_ = [SubjectFolderIn '\OCT Volumes\'];

%% Running
findFocusInBScan;
stitchOverview;
stitchZStack

%% See if upload is needed
if (~inputFolderAWS && outputFolderAWS)
    disp('Uploading files to AWS');
    
    %Copy to the cloud
    awsCopyFileFolder(SubjectFolderIn,SubjectFolderOut);
    
    %Delete local folder
    rmdir(SubjectFolderIn,'s');
end

