%This script runs all preprocessing sequentially

%% Inputs
SubjectFolderIn = 's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01';
SubjectFolderOut = SubjectFolderIn; %Where to save folder to

isRunInAutomatedMode = true; %When set to false, will allow human more control to select info

%For debug purpose, skip the uploading part
isProcessOnly = false; %No uploading to the cloud
deleteFolderAfterUpload = false; %Would you like to delete data after uploading to the cloud or ask for manual delete?

%% Setup environment
if (exist('SubjectFolderIn_','var'))
	disp(['Processing input: ' SubjectFolderIn_ ]);
    SubjectFolderIn = SubjectFolderIn_;
    SubjectFolderOut = SubjectFolderOut_;
end

%Processing
if exist('isProcessOnly_','var') 
	disp('Processing only mode, will not upload to cloud');
	isProcessOnly = isProcessOnly_;
end
if (isProcessOnly)
    %If only processing, no need to upload to the cloud
    SubjectFolderOut = SubjectFolderIn;
end

%Automated only
if exist('isRunInAutomatedMode_','var')
	isRunInAutomatedMode = isRunInAutomatedMode_;
end
if ~isRunInAutomatedMode
	input('Once we click on enter script will run, would you like to edit files? Click enter when ready');
end

if ~awsIsAWSPath(SubjectFolderIn_ ) && ~exist(SubjectFolderIn_,'dir')
	disp(['Input folder non existing: ' SubjectFolderIn_ '. Probably already upload to the cloud']);
	disp('Skipping that one');
	return;
end

OCTVolumesFolder_ = [SubjectFolderIn '\OCTVolumes\'];

%% Do we need to upload to the cloud?
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
isUploadToCloud = ~inputFolderAWS && outputFolderAWS;
if (isProcessOnly)
    isUploadToCloud = false;
end

%% Start by uploading to the cloud
if(isUploadToCloud && ...
	isRunInAutomatedMode) %In manual mode run code first than upload to the cloud
    disp('Uploading files to AWS');
    
    %Copy to the cloud
    awsCopyFileFolder(SubjectFolderIn,SubjectFolderOut);
    
    disp('Uploading Completed');
    disp('Preprocessing Using local copy...');
end

%% Running
try
	%Create one parallel pull for all
	setupParpolOCTPreprocess();
	
    fprintf('%s Running findFocusInBScan.\n',datestr(datetime));
    findFocusInBScan;
    close all;
    
    fprintf('%s Running stitchOverview.\n',datestr(datetime));
    stitchOverview;
    close all;
    
    fprintf('%s Running stitchZStack.\n',datestr(datetime));
    stitchZStack
    close all;
	
	%Upload new files to the cloud, but only if processing was finished correctly
	if(isUploadToCloud)
		if isRunInAutomatedMode
			fprintf('%s Uploading difference to the cloud.\n',datestr(datetime));
			
			%Upload Volumes
			d = dir(OCTVolumesFolder_); 
			for i=1:length(d)
				switch (d(i).name)
					case {'.','..','Overview','Volume'}
						%Do nothing, these were already uploaded
					otherwise
						%Copy to the cloud
						awsCopyFileFolder([d(i).folder '\' d(i).name], ...
							[SubjectFolderOut '/OCTVolumes/' d(i).name]);
				end
			end
			%Upload Logs
			d = dir(SubjectFolderIn); 
			for i=1:length(d)
				switch (d(i).name)
					case {'.','..','OCTVolumes'}
						%Do nothing, these were already uploaded
					otherwise
						%Copy to the cloud
						awsCopyFileFolder([d(i).folder '\' d(i).name], ...
							[SubjectFolderOut '/' d(i).name],false); %Verboose mode off
				end
			end
		else %ran manually need to upload everything
			disp('Uploading files to AWS');
			awsCopyFileFolder(SubjectFolderIn,SubjectFolderOut);
		end
		
		if deleteFolderAfterUpload
			%Delete local folder, its done
			rmdir(SubjectFolderIn,'s');
		end
	end
    
    fprintf('%s Done Running.\n',datestr(datetime));
catch ME 
    %% Error Hendle. If error happend during processing we still want to upload the data
	disp(' '); 
	disp('Error Happened'); 
	for i=1:length(ME.stack) 
		ME.stack(i) 
	end 
	disp(ME.message); 
   
    if (false && isUploadToCloud && deleteFolderAfterUpload) %Only manual cleaning
        disp('Cleaning up local folder (as we alrady uploaded to the cloud)');
        %Delete local folder
        rmdir(SubjectFolderIn,'s');
    end
    
    error('Aborting');
end 

fprintf('%s Finish.\n',datestr(datetime));
