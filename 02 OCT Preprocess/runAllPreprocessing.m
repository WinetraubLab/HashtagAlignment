%This script runs all preprocessing sequentially

%% Inputs
OCTVolumesFolderIn = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-00/OCT Volumes/';
OCTVolumesFolderOut = OCTVolumesFolderIn; %Where to save folder to

%% Setup environment
if (isRunningOnJenkins()) %Get inputs from Jenkins
    OCTVolumesFolderIn = OCTVolumesFolderIn_;
    OCTVolumesFolderOut = OCTVolumesFolderOut_;
end

if (strcmpi(OCTVolumesFolderIn(1:3),'s3:'))
    inputFolderAWS = true;
else
    inputFolderAWS = false;
end

if (strcmpi(OCTVolumesFolderOut(1:3),'s3:'))
    outputFolderAWS = true;
else
    outputFolderAWS = false;
end

runninAll = true;
OCTVolumesFolder_ = OCTVolumesFolderIn;

%% Running
stitchOverview;
findFocusInBScan;
stitchZStack

%% See if upload is needed
if (~inputFolderAWS && outputFolderAWS)
    disp('Uploading files to AWS');
    awsCopyFileFolder(OCTVolumesFolderIn,OCTVolumesFolderOut);
end

