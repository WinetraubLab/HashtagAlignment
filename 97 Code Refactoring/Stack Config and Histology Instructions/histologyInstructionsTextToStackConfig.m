function histologyInstructionsTextToStackConfig(subjectPath)
% This function converts histology instructions text file to stack config. 
% (used by LC and some LD) Written at Jan 10, 2020.
%%

if ~exist('subjectPath','var')
    subjectPath = s3SubjectPath('02','LC');
end

readFileFromOperational = false; % Set to false if reading file from the 'deprecated' folder

%% Figure out if this subject has the older version of histology instructions as we expect.
logsFloder = awsModifyPathForCompetability([subjectPath '/Log/01 OCT Scan and Pattern/']);
depricatedFolder = awsModifyPathForCompetability([subjectPath 'Log/00 Depreciated Files Dont Use/']);
slidesFolder = awsModifyPathForCompetability([subjectPath '/Slides/']);

try
    if readFileFromOperational
        % Any fileDatastore request to AWS S3 is limited to 1000 files in 
        % MATLAB 2021a. Due to this bug, we have replaced all calls to 
        % fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
        % 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
        ds = fileDatastore([logsFloder 'histoInstructions.txt'],'ReadFcn',@fileread);
    else
        ds = fileDatastore([depricatedFolder 'histoInstructions.txt'],'ReadFcn',@fileread);
    end
    hiText = ds.read;
catch
    disp('Couldn''t load Histology Instructions Text file - does it even exist?, Skipping');
    return;
end

%% Parse text file to generate a stack config
lines = split(hiText,newline);

currentDepth_um = 0;
sectionDepthsRequested_um = [];
isMetHistologyInstructions = false;
inputs = {}; %Inputs that will go to generate stack config
clear sc
%Loop over every line
for i=1:length(lines)
    l = lines{i};

    if(contains(lower(l),'sample id'))
        l = l(strfind(l,':')+1:end);
        inputs = [inputs {'sampleID', strtrim(l)}];
    elseif(contains(lower(l),'scanned by'))
        l = l(strfind(l,':')+1:end);
        inputs = [inputs {'operator', strtrim(l)}];
    elseif(contains(lower(l),'date'))
        l = l(strfind(l,':')+1:end);
        inputs = [inputs {'date', strtrim(l)}];
    elseif(contains(lower(l),'we want to cut sections at the same side as black dot'))
        inputs = [inputs {'startCuttingAtDotSide', 1}];
    elseif(contains(lower(l),'we want to cut sections at the side opposite to the black dot'))
        inputs = [inputs {'startCuttingAtDotSide', -1}];
    elseif(contains(lower(l),'instructions for histology'))
        isMetHistologyInstructions = true;
    elseif(contains(lower(l),'take one slide / section') && isMetHistologyInstructions)
        sectionDepthsRequested_um = [sectionDepthsRequested_um currentDepth_um];
    elseif(contains(lower(l),'go in')) && ~contains(lower(l),'we would like') && isMetHistologyInstructions
        l = l((strfind(lower(l),'go in')+5):end);
        l = l(1:(strfind(lower(l),'um')-1));
        l = strtrim(l);
        if isnan(str2double(l))
            error('Error processing line %s',lines{i});
        end
        currentDepth_um = currentDepth_um+str2double(l)*1.7;
    elseif(contains(lower(l),'take') && contains(lower(l),'sections per slide')) && isMetHistologyInstructions
        l = l((strfind(lower(l),'slide (')+7):end);
        l = l(1:(strfind(lower(l),' sections')-1));

        nSections = str2double(strtrim(l));

        %Section interval is on the next line
        l = lower(lines{i+1});
        l = l((strfind(l,'interval of')+11):end);
        l = l(1:(strfind(l,'um')-1));
        interval_um = (str2double(strtrim(l))+5)*10/5;

        n = 0:(nSections-1);
        sectionDepthsRequested_um = [sectionDepthsRequested_um (currentDepth_um+n*interval_um)];
        currentDepth_um = max(sectionDepthsRequested_um);
        
        estimatedDistanceFromFullFaceToOCTOrigin_um = mean(sectionDepthsRequested_um);
        
        inputs = [inputs {'sectionDepthsRequested_um',sectionDepthsRequested_um, ...
            'estimatedDistanceFromFullFaceToOCTOrigin_um', estimatedDistanceFromFullFaceToOCTOrigin_um}];

        %Add it to HI
        if ~exist('sc','var')
            %New HI
            sc = scGenerateStackConfig(inputs);
        else
            sc = scGenerateStackConfig([{'appendToSC', sc} inputs]);
        end
        sectionDepthsRequested_um = []; %Reset depths
        currentDepth_um = 0;
    else
        %Do nothing
    end
end

%% Finalize
% Write stack config json file and read from that
awsWriteJSON(sc,[slidesFolder '/StackConfig.json']);
scGenerateHistologyInstructionsFile(sc,[logsFloder 'HistologyInstructions.pdf']);

% Cleanup
if (readFileFromOperational)
    awsCopyFileFolder([logsFloder 'histoInstructions.txt'], ...
        [depricatedFolder 'histoInstructions.txt']);
    awsRmFile([logsFloder 'histoInstructions.txt']);
end
