%This script runs all preprocessing sequentially

%% Inputs
SubjectFolderIn = s3SubjectPath('01');
SubjectFolderOut = SubjectFolderIn; %Where to save folder to

isRunInAutomatedMode = true; %When set to false, will allow human more control to select info

% Specify what kind of processing is needed
isUploadToCloud = true; % Should data be uploaded to S3?
deleteFolderAfterUpload = true; %Would you like to delete data after uploading to the cloud or ask for manual delete?
isPreprocess = true; % When set to false, will not preprocess, just upload

%% Setup environment
if (exist('SubjectFolderIn_','var'))
	fprintf('%s Input: "%s"\n',datestr(datetime),SubjectFolderIn_);
    SubjectFolderIn = SubjectFolderIn_;
    SubjectFolderOut = SubjectFolderOut_;
end

% Set up processing and uploading switches
if exist('isUploadToCloud_','var') 
	isUploadToCloud = isUploadToCloud_;
end
if exist('isPreprocess_','var') 
	isPreprocess = isPreprocess_;
end

%Automated only
if exist('isRunInAutomatedMode_','var')
	isRunInAutomatedMode = isRunInAutomatedMode_;
end
if ~isRunInAutomatedMode
	input('Once we click on enter script will run, would you like to edit files? Click enter when ready');
end

%% Check Folders

if ~awsExist(SubjectFolderIn)
     disp(['Input folder "' SubjectFolderIn '" does not exist. Skipping']);
     return;
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

% if requesting to upload to the cloud, make sure folder is not already in s3 :)
if (isUploadToCloud && inputFolderAWS)
     disp(['Input folder "' SubjectFolderIn '" is already in the cloud, will not override. Skipping']);
     return;
end

if (isUploadToCloud && ~outputFolderAWS)
     disp(['Output folder "' outputFolderAWS '" is not in the cloud, cannot upload. Skipping']);
     return;
end

if (~isUploadToCloud)
    % If only processing, no need to upload to the cloud
	disp('Will not upload to cloud');
    SubjectFolderOut = SubjectFolderIn;
end

OCTVolumesFolder_ = [SubjectFolderIn '\OCTVolumes\'];

fprintf('%s Input checks completed.\n',datestr(datetime));

%% Start by uploading to the cloud
if(isUploadToCloud && ...
	isRunInAutomatedMode) %In manual mode run code first than upload to the cloud, but in auto mode upload first.
	fprintf('%s Uploading files to AWS ...\n',datestr(datetime));
    
    %Copy to the cloud
    awsCopyFileFolder(SubjectFolderIn,SubjectFolderOut,true);
    
	fprintf('%s Uploading Completed.\n',datestr(datetime));
	fprintf('%s Preprocessing Using local copy...\n',datestr(datetime));
end

%% Running
try
	if isPreprocess
		%Create one parallel pull for all
		setupParpolOCTPreprocess();
		
		fprintf('%s Running findFocusInBScan.\n',datestr(datetime));
		findFocusInBScan;
		close all;
		
		fprintf('%s Running stitchOverview.\n',datestr(datetime));
		stitchOverview;
		close all;
		
		fprintf('%s Running stitchVolume.\n',datestr(datetime));
		stitchVolume
		close all;
    else
        fprintf('%s skipping preprocess.\n',datestr(datetime));
	end
	
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
		else %ran manually. Need to upload everything
			fprintf('%s Uploading files to AWS...\n',datestr(datetime));
			awsCopyFileFolder(SubjectFolderIn,SubjectFolderOut,true);
			fprintf('%s Uploading complete.\n',datestr(datetime));
		end
		
		if deleteFolderAfterUpload
			%Delete local folder, its done
			rmdir(SubjectFolderIn,'s');
		end
	end
    
    fprintf('%s Done Running.\n',datestr(datetime));
catch ME 
    %% Error Hendle. If error happend during processing we still want to upload the data
	fprintf('\n%s Error Happened.\n',datestr(datetime));
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
