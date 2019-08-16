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
    pds = fileDatastore(yOCTMainFolder,'ReadFcn',@load,'FileExtensions','.m','IncludeSubfolders',true);  
    addAttachedFiles(p,pds.Files);
    
else
    %Assuming all is fine
    
end