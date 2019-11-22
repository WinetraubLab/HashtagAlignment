%This is a utility script that runs over all subjects and change something
%(what exactly is up to you to edit)
%% Inputs 
[subjectsPath,subjectsName] = ...
    s3GetAllSubjectsInLib('LC'); %Set lib (LC, LD etc, or leave empty for latest lib)

%Do you wish to run on subjects or slides?
isRunOnSubjects = false; 
isRunOnSlides = true;

%% Loop Over all subjects and make the change (subject related)
if isRunOnSubjects
    disp('Running on Subjects');
    for si = 1:length(subjectsPath)
        subjectPath = subjectsPath{si};
        disp(['Processing ' subjectsName{si}]);

        %% Make the change <--HERE-->
        
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