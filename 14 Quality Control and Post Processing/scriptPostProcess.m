% Compute quality control on all images of a subject

subjectPath_ = s3SubjectPath('01','LE');
[~,sectionNames] = s3GetAllSlidesOfSubject(subjectPath_);

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