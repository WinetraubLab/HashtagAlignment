%This script converts JSON version to the latest version

%File path to search for JSONS
filePath =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/';

%% Search for JSON files
fprintf('%s Finding JSON Files\n',datestr(now));

folder = awsModifyPathForCompetability([fileparts(filePath) '/']);
% Any fileDatastore request to AWS S3 is limited to 1000 files in 
% MATLAB 2021a. Due to this bug, we have replaced all calls to 
% fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
% 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
ds = imageDatastore(folder,'ReadFcn',@awsReadJSON,'FileExtensions','.json','IncludeSubfolders',true);
ds.Files = ds.Files(cellfun(@(x)(contains(x,'SlideConfig')),ds.Files));

jsonIns = ds.readall;
fps = ds.Files;
%% Loop over all JSON files and upgrade version
fprintf('%s Conversion Started\n',datestr(now));
for i=1:length(fps)
    jsonIn = jsonIns{i};
    jsonFilePath = fps{i};
       
    clear jsonOut;
    lastVersion = 1.2;
    jsonOut.version = lastVersion;
    switch(jsonIn.version)
        case 1        
            jsonOut.photobleachedLinesImagePath = jsonIn.photobleachedLinesImagePath;
            jsonOut.brightFieldImagePath = jsonIn.brightFieldImagePath;
            jsonOut.FM.pixelSize_um = jsonIn.FMRes;
            jsonOut.FM.imagedAt = datestr(datetime(strrep(jsonIn.FMWhenWasItScanned,'2019','2019 '))); %V
            error('What? are you still using version 1?');
     
        case 1.1
            jsonOut.photobleachedLinesImagePath = jsonIn.photobleachedLinesImagePath;
            jsonOut.brightFieldImagePath = jsonIn.brightFieldImagePath;
            jsonOut.FM.pixelSize_um = jsonIn.FM.pixelSize_um;
            jsonOut.FM.imagedAt = datestr(datetime(strrep(jsonIn.FM.imagedAt,'2019','2019 '))); %Was Fixed during 1.1, but some may sliped away
            
            %Image size
            plFP = awsModifyPathForCompetability([fileparts(jsonFilePath) '/' jsonOut.photobleachedLinesImagePath]);
            % Any fileDatastore request to AWS S3 is limited to 1000 files in 
            % MATLAB 2021a. Due to this bug, we have replaced all calls to 
            % fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
            % 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
            ds = imageDatastore(plFP,'ReadFcn',@imfinfo);
            info = ds.read;
            jsonOut.FM.imageSize_pix = [info.Height info.Width];
            
            if isfield(jsonIn.FM,'fiducialLines')
                jsonOut.FM.fiducialLines = jsonIn.FM.fiducialLines;
            end
            if isfield(jsonIn.FM,'singlePlaneFit')
                jsonOut.FM.singlePlaneFit = jsonIn.FM.singlePlaneFit;
            end
            
        case {lastVersion,1.2} %Version 1.2 - started August 30, 2019
            
            %Do nothing, its already in latest version
            jsonOut = jsonIn;
            
        otherwise
            error('Dont know how to convert from that version');
    end
    
    if (jsonIn.version ~= lastVersion)
        %JSON update is required
        awsWriteJSON(jsonOut,fps{i});
    end
    
    %Progress report
    if ~exist('tt','var') || toc(tt) > 60*2
        tt = tic();
        fprintf('%s Finished converting %d out of %d [%.1f%%]\n',datestr(now),i,length(fps),100*i/length(fps));
    end    
end

fprintf('%s Done!\n',datestr(now));