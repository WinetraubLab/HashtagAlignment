%This script converts JSON version to the latest version

%File path to search for JSONS
filePath =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/';

%% Search for JSON files

folder = awsModifyPathForCompetability([fileparts(filePath) '/']);
ds = fileDatastore(folder,'ReadFcn',@awsReadJSON,'FileExtensions','.json','IncludeSubfolders',true);
ds.Files = ds.Files(cellfun(@(x)(contains(x,'SlideConfig')),ds.Files));

jsonIns = ds.readall;
fps = ds.Files;
%% Loop over all JSON files and upgrade version
for i=1:length(ds.Files)
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
            
            if isfield(jsonIn.FM,'fiducialLines')
                jsonOut.FM.fiducialLines = jsoIn.FM.fiducialLines;
            end
            if isfield(jsonIn.FM,'singlePlaneFit')
                jsonOut.FM.singlePlaneFit = jsoIn.FM.singlePlaneFit;
            end
            
            plFP = awsModifyPathForCompetability([fileparts(jsonFilePath) '/' jsonOut.photobleachedLinesImagePath]);
            ds = fileDatastore(plFP,'ReadFcn',@imfinfo);
            info = ds.read;
            json.FM.imageSize_pix = [info.Height info.Width];
            
        case {lastVersion,1.2} %Version 1.2 - started August 30, 2019
            
            %Do nothing, its already in latest version
            jsonOut = jsonIn;
            
        otherwise
            error('Dont know how to convert from that version');
    end
    
    awsWriteJSON(jsonOut,fps{i});
end

disp('Done');