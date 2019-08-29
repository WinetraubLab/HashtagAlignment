%This function identifies lines and compute basic alignment (single plane)

%% Inputs
slideFilepath =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01/Slides/Slide02_Section02/SlideConfig.json';

rewriteMode = true; %Don't re write information

%% Jenkins?
if exist('slideFilepath_','var')
    slideFilepath = slideFilepath_;
end

%% Extract Slide Folder
disp([datestr(now) ' Loading JSON']);
slideFolder = awsModifyPathForCompetability([fileparts(slideFilepath) '/']);
ds = fileDatastore(slideFolder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
slideJsonFilePath = ds.Files{1};
slideJson = ds.read();

octVolumeFolder = awsModifyPathForCompetability([slideFolder '../../OCTVolumes/']);
ds = fileDatastore(octVolumeFolder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
octVolumeJsonFilePath = ds.Files{1};
octVolumeJson = ds.read();

%% Load Flourecent image
disp([datestr(now) ' Loading Flourecent Image']);
ds = fileDatastore(awsModifyPathForCompetability([slideFolder slideJson.photobleachedLinesImagePath]),'ReadFcn',@imread);
histologyFluorescenceIm = ds.read();

%% Identify Lines
disp([datestr(now) ' Identify Lines']);

f = slideJson.FM.fiducialLines;
f = fdlnSortLines(f); %Sort lines such that they are organized by position, left to right
fOrig = f;

isidentifySuccssful = false;
if ~contains([f.group],'1') && ~rewriteMode
    %Identification already happend, skip
    isidentifySuccssful = true;
else
    
    %Get z position of the interface bettween tissue and gel, because that was
    %the position we set at the begning
    zInterface = octVolumeJson.VolumeOCTDimensions.z.values(octVolumeJson.focusPositionInImageZpix); %[um]
    zInterface = zInterface/1000; %[mm]
    grT = [f.group] == 't';
    grTi = find(grT);
    for i=grTi
        f(i).linePosition_mm = zInterface;
    end
    
    group1I = [f.group]=='1' | [f.group]=='v';
    group2I = [f.group]=='2' | [f.group]=='h';
    
    if (sum(group1I) < 3 || sum(group2I) < 3)
        disp('Not enugh lines to preform identification, make that manually');
    else
        f(group1I) = fdlnIdentifyLines(...
            f(group1I), ...
            octVolumeJson.vLinePositions,octVolumeJson.hLinePositions);
        f(group2I) = fdlnIdentifyLines(...
            f(group2I), ...
            octVolumeJson.vLinePositions,octVolumeJson.hLinePositions);

        if (sum([f.group] ~= f(1).group) ~= 0)
            isidentifySuccssful = true;
        end
    end
end

%% Compute U,V,H & stats
if (isidentifySuccssful)
    singlePlaneFit = alignSignlePlane(f,slideJson.FM.pixelSize_um);
    plotSignlePlane(singlePlaneFit,f,histologyFluorescenceIm,octVolumeJson);

else
    plotSignlePlane(NaN,f,histologyFluorescenceIm,octVolumeJson);
end

%% Prompt user, would they like to update before we save?
if (rewriteMode)
	button = questdlg('Would you like to manually override line identification?','Q','Yes','No','No');
    if (strcmp(button,'Yes'))
        fi = [f.group] ~= 't';
        fi = find(fi);

        fprintf('vLinePositions [mm] = %s\n',sprintf('%.3f ',octVolumeJson.vLinePositions));
        fprintf('hLinePositions [mm] = %s\n',sprintf('%.3f ',octVolumeJson.hLinePositions));
        fprintf('Please enter line groups (left to right), seperate by comma or space [can be v or h]\n');
        fprintf(   'Orig File: %s\n',sprintf('%s',[transpose([fOrig(fi).group]) repmat(' ',length(fi),1)]'))
        fprintf(   'Best Fit:  %s\n',sprintf('%s',[transpose([f(fi).group]) repmat(' ',length(fi),1)]'))
        gr = input('Input:     ','s');
        gr = strsplit(gr,{',',' '});
        gr(cellfun(@isempty,gr)) = [];

        fprintf('Please enter line positions (left to right), seperate by comma or space [in mm]\n');
        fprintf(    'Orig File: %s\n',sprintf('%.3f ',[fOrig(fi).linePosition_mm]));  
        fprintf(    'Best Fit:  %s\n',sprintf('%.3f ',[f(fi).linePosition_mm]));  
        pos = input('Input:     ','s');
        pos = strsplit(pos,{',',' '});
        pos = cellfun(@str2double,pos);

        if length(fi) ~= length(pos) || length(fi) ~= length(gr)
           error('Missing some lines');
        end

        for i=1:length(fi)
           f(fi(i)).group = gr{i};
           f(fi(i)).linePosition_mm = pos(i);
        end
        singlePlaneFit = alignSignlePlane(f,slideJson.FM.pixelSize_um);
        plotSignlePlane(singlePlaneFit,f,histologyFluorescenceIm,octVolumeJson);
   end
end

slideJson.FM.singlePlaneFit = singlePlaneFit;
slideJson.FM.fiducialLines = f;

%% Save to JSON & figure
if (rewriteMode)
    disp([datestr(now) ' Saving Updated JSON & Figure']);
    awsWriteJSON(slideJson,slideJsonFilePath);
    
    if exist('SlideAlignment.png','file')
        if (awsIsAWSPath(slideJsonFilePath))
            %Upload to AWS
            awsCopyFileFolder('SlideAlignment.png',[fileparts(slideJsonFilePath) '/SlideAlignment.png']);
        else
            copyfile('SlideAlignment.png',[fileparts(slideJsonFilePath) '\SlideAlignment.png']);
        end   
    end
end