% In order to bring an old version of datafiles up to speed (to convert to
% current format) use this script. It runs over all subjects of some
% library for the purpose of finding old / unsupported data files and
% converting them to current version

%% Inputs 

% Which library to run on
[subjectsPath,subjectsName] = ...
    s3GetAllSubjectsInLib('LC'); %Set lib (LC, LD etc, or leave empty for latest lib)

% Will the script run on subjects or slides?
runOn = 'slides'; % Can be 'subjects' or 'slides'

% Function to run for each subject / slide
% Function handle interface is func(rootFolder) where root folder will be
% either the subject folder or the slide folder acording to runOn.
%funcToRun = @(rootFolder)(rootFolder);
funcToRun = @updateWasAlignmentSuccessful; %recomputeStackAlignment, recomputeSlideAlignment
%funcToRun = @changeDispersionParameterA2QuadraticTerm;

%% Loop Over all subjects and make the change (subject related)
if strcmpi(runOn,'subjects')
    disp('Running on Subjects');
    for si = 1:length(subjectsPath)
        subjectPath = subjectsPath{si};
        disp(['Processing ' subjectsName{si}]);

        funcToRun(subjectPath);
    end
end

%% Loop over all slides of each subject
if strcmpi(runOn,'slides')
    disp('Running on Slides')
    for si = 1:length(subjectsPath)
        subjectPath = subjectsPath{si};
        disp(['Processing ' subjectsName{si}]);
        tic;
        try
            [slidesPath,sectionNames] = s3GetAllSlidesOfSubject(subjectPath);
        catch
            disp('Skipping this subject, no slides');
            continue;
        end

        for sli = 1:length(slidesPath)
            slidePath = slidesPath{sli};
            disp(['  Processing ' sectionNames{sli}]);

            funcToRun(slidePath);
        end
        toc;
    end
end