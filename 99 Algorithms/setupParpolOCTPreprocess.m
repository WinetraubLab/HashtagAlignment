function setupParpolOCTPreprocess()
%Setup parallel pool, attach everything we need

p=gcp('nocreate');
if ~isempty(p)
    %kill prev parpool before starting this one if it has SpmdEnabled flag
    if (p.SpmdEnabled)
        delete(p);
    end
end

if isempty(p)
    %Parpool didnt start yet, start it
    p=parpool('SpmdEnabled',false);
    currentFileFolder = fileparts(mfilename('fullpath'));
    yOCTMainFolder = [currentFileFolder '..\..\'];
    % Any fileDatastore request to AWS S3 is limited to 1000 files in 
    % MATLAB 2021a. Due to this bug, we have replaced all calls to 
    % fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
    % 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
    pds = imageDatastore(yOCTMainFolder,'ReadFcn',@load,'FileExtensions','.m','IncludeSubfolders',true);  
    addAttachedFiles(p,pds.Files);
    
else
    %Assuming all is fine
    
end