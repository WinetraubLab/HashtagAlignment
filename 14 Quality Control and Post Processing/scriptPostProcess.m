% Compute quality control on all images of a subject

subjectPath_ = s3SubjectPath('02','LE');
[~,sectionNames] = s3GetAllSlidesOfSubject(subjectPath_);


%% Run on all subjects in a loop
HRef = [];
ERef = [];
for i=1:length(sectionNames)
    sectionName_ = sectionNames{i};
    try
        collectHERef
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