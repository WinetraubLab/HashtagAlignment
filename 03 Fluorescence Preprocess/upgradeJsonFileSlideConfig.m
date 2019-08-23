%This script converts JSON version to the latest version

%File path to search for JSONS
filePath =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/';

%% Search for JSON files

folder = awsModifyPathForCompetability([fileparts(filePath) '/']);
ds = fileDatastore(folder,'ReadFcn',@awsReadJSON,'FileExtensions','.json','IncludeSubfolders',true);
ds.Files = ds.Files(cellfun(@(x)(contains(x,'SlideConfig')),ds.Files));

jsonIns = ds.readall;
%% Loop over all JSON files and upgrade version
for i=1:length(ds.Files)
    jsonIn = jsonIns{i};
    
    clear jsonOut;
    switch(jsonIn.version)
        case 1
            jsonOut.version = 1.1;
            jsonOut.photobleachedLinesImagePath = jsonIn.photobleachedLinesImagePath;
            jsonOut.brightFieldImagePath = jsonIn.brightFieldImagePath;
            jsonOut.FM.pixelSize_um = jsonIn.FMRes;
            jsonOut.FM.imagedAt = datestr(datetime(strrep(jsonIn.FMWhenWasItScanned,'2019','2019 '))); %V
     
        case 1.1
            %Do nothing, its already in latest version
            jsonOut = jsonIn;
            
        otherwise
            error('Dont know how to convert from that version');
    end
    
    awsWriteJSON(jsonOut,ds.Files{i});
end

disp('Done');