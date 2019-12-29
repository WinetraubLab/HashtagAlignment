%This is a utility script that runs over all subjects and change something
%(what exactly is up to you to edit)
%% Inputs 
[subjectsPath,subjectsName] = ...
    s3GetAllSubjectsInLib('LC'); %Set lib (LC, LD etc, or leave empty for latest lib)

%Do you wish to run on subjects or slides?
isRunOnSubjects = true; 
isRunOnSlides = false;

%% Loop Over all subjects and make the change (subject related)
if isRunOnSubjects
    disp('Running on Subjects');
    for si = 1:length(subjectsPath)
        subjectPath = subjectsPath{si};
        disp(['Processing ' subjectsName{si}]);

        %% Make the change <--HERE-->
        jsonFiles = {...
            [subjectPath '/OCTVolumes/Volume/ScanInfo.json'], ...
            [subjectPath '/OCTVolumes/Overview/ScanInfo.json'], ...
            };
        ini = yOCTReadProbeIniToStruct('Y:\Work\_de la Zerda Lab Scripts\HashtagAlignmentRepo\01 OCT Scan and Pattern\Thorlabs\Probe - Olympus 10x.ini');
        
        for i=1:length(jsonFiles)
            json = awsReadJSON(jsonFiles{i});
            
            ini.DynamicFactorX = json.xRange;
            ini.DynamicOffsetX = json.xOffset;
            json.xRange = 1;
            json.xOffset = 0;
            json.version = 1.1;
            
            if (isfield(json,'lensWorkingDistance'))
                json = rmfield(json,'lensWorkingDistance');
            end
            json.octProbeIni = ini;
           
            awsWriteJSON(json,jsonFiles{i});
        end
        
        jsonFiles = [subjectPath 'OCTVolumes/ScanConfig.json'];
        json = awsReadJSON(jsonFiles);
        
        if (isfield(json,'lensWorkingDistance'))
            json = rmfield(json,'lensWorkingDistance');
        end
        if (isfield(json,'octProbeLensWorkingDistance'))
            json = rmfield(json,'octProbeLensWorkingDistance');
        end
        if (isfield(json,'octProbeFOV'))
            json = rmfield(json,'octProbeFOV');
        end
        
        json = rmfield(json,'scaleX');
        json = rmfield(json,'scaleY');
        json = rmfield(json,'offsetX');
        json = rmfield(json,'offsetY');
        json.version = 2.1;
        
        is1 = json.volume.isScanEnabled;
        json.volume = awsReadJSON(jsonFiles{1});
        json.volume.isScanEnabled = is1;
        
        is1 = json.overview.isScanEnabled;
        json.overview = awsReadJSON(jsonFiles{2});
        json.overview.isScanEnabled = is1;
        
        awsWriteJSON(json,jsonFiles);
        
        %Do nothing
    end
end

%% Loop over all slides of each subject
if isRunOnSlides
    disp('Running on Slides')
    for si = 1:length(subjectsPath)
        subjectPath = subjectsPath{si};
        disp(['Processing ' subjectsName{si}]);
        tic;
        try
            slidesPath = s3GetAllSlidesOfSubject(subjectPath);
        catch
            disp('Skipping this subject, no slides');
            continue;
        end

        for sli = 1:length(slidesPath)
            slidePath = slidesPath{sli};
            
            %% Make the change <--HERE-->
            
            slideConfigJson = awsReadJSON([slidePath 'SlideConfig.json']);
            fprintf('Is Histology Image File Exist: %d\n',isfield(slideConfigJson,'histologyImageFilePath'));
            if isfield(slideConfigJson,'histologyImageFilePath') && ...
                    ~strcmp(slideConfigJson.histologyImageFilePath,'FM_HAndE.tif')
                %We need to edit
                disp(['Slide to edit' slidePath])
                                
                %Copy file
                awsCopyFileFolder([slidePath slideConfigJson.histologyImageFilePath],[slidePath 'FM_HAndE.tif'],true)
                
                %Remove old file
                awsRmFile([slidePath slideConfigJson.histologyImageFilePath]);
                
                %Update filed
                slideConfigJson.histologyImageFilePath = 'FM_HAndE.tif';
                awsWriteJSON(slideConfigJson,[slidePath 'SlideConfig.json']);
            end
            
            %Do nothing
        end
        toc;
    end
end