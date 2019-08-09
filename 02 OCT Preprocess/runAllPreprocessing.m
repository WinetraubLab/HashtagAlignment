%This script runs all preprocessing sequentially

%% Inputs
SubjectFolderIn = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01';
SubjectFolderOut = SubjectFolderIn; %Where to save folder to

%% Setup environment
if (isRunningOnJenkins()) %Get inputs from Jenkins
    disp(['Processing input: ' SubjectFolderIn_ ]);
    SubjectFolderIn = SubjectFolderIn_;
    SubjectFolderOut = SubjectFolderOut_;
    
    if ~awsIsAWSPath(SubjectFolderIn_ ) && ~exist(SubjectFolderIn_,'dir')
        disp(['Input folder non existing: ' SubjectFolderIn_ '. Probably already upload to the cloud']);
        disp('Skipping that one');
        return;
    end
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
    
    disp('Uploading Completed');
    disp('Preprocessing Using local copy...');
end

%% Running
try
    fprintf('%s Running findFocusInBScan.\n',datestr(datetime));
    findFocusInBScan;
    close all;
    
    fprintf('%s Running stitchOverview.\n',datestr(datetime));
    stitchOverview;
    close all;
    
    fprintf('%s Running stitchZStack.\n',datestr(datetime));
    stitchZStack
    close all;
    
    fprintf('%s Done Running.\n',datestr(datetime));
catch ME 
    %% Error Hendle. If error happend during processing we still want to upload the data
	disp(' '); 
	disp('Error Happened'); 
	for i=1:length(ME.stack) 
		ME.stack(i) 
	end 
	disp(ME.message); 
    
    if (isUploadToCloud)
        disp('Cleaning up local folder (as we alrady uploaded to the cloud)');
        %Delete local folder
        rmdir(SubjectFolderIn,'s');
    end
    
    error('Aborting');
end 

%% Upload new files to the cloud
if(isUploadToCloud)
    fprintf('%s Uploading difference to the cloud.\n',datestr(datetime));
    
    %Delete files that were uploaded before
    delete([SubjectFolderIn '\*.srr']);
    
    %Copy to the cloud
    awsCopyFileFolder(SubjectFolderIn,SubjectFolderOut);
    
    %Delete local folder, its done
    rmdir(SubjectFolderIn,'s');
end

fprintf('%s Finish.\n',datestr(datetime));
