%This script runs all preprocessing sequentially

%% Inputs
SubjectFolderIn = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01';
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

%% Start by uploading to the cloud
isUploadToCloud = ~inputFolderAWS && outputFolderAWS;

if(isUploadToCloud)
    disp('Uploading files to AWS');
    
    %Copy to the cloud
    awsCopyFileFolder(SubjectFolderIn,SubjectFolderOut);
    
    disp('Preprocessing Using local copy...');
end

%% Running
try
    findFocusInBScan;
    close all;
    
    stitchOverview;
    close all;
    
    stitchZStack
    close all;
catch ME 
    %% Error Hendle. If error happend during processing we still want to upload the data
	disp(' '); 
	disp('Error Happened'); 
	for i=1:length(ME.stack) 
		ME.stack(i) 
	end 
	disp(ME.message); 
    
    if (isUploadToCloud)
        disp('Cleaning up local folder (as we alrady uploaded to the cloud');
        %Delete local folder
        rmdir(SubjectFolderIn,'s');
    end
    
    error('Aborting');
end 

%% Upload new files to the cloud
if(isUploadToCloud)
    disp('Uploading difference to the cloud');
    
    %Delete files that were uploaded before
    delete([SubjectFolderIn '\*.srr']);
    
    %Copy to the cloud
    awsCopyFileFolder(SubjectFolderIn,SubjectFolderOut);
    
    %Delete local folder, its done
    rmdir(SubjectFolderIn,'s');
end