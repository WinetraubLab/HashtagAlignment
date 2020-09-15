% Compute quality control on all images of a subject

%% Inputs
subjectPath_ = s3SubjectPath('43','LG');

%% Jenkins & get section path
if exist('subjectPath__','var')
    subjectPath_ = subjectPath__;
end

[~,sectionNames] = s3GetAllSlidesOfSubject(subjectPath_);

%% Run on all subjects in a loop
HRef = [];
ERef = [];
for i=1:length(sectionNames)
    sectionName_ = sectionNames{i};
    try
        collectHERef
    catch ME
        warning('collectHERef failed, message: %s',ME.message)
    end
end

HE0 = [median(HRef,2), median(ERef,2)];

%% Run on all subjects in a loop
for i=1:length(sectionNames)
    sectionName_ = sectionNames{i};
    
    disp(sectionName_);
    try
        scriptPostProcess_SingleSection; 
    catch ME
       warning('Error happend: %s. Continuing...',ME.message) 
    end 
end
disp('Done');
close all;