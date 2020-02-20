function [sectionPaths, sectionNames, sectionRootFolder] = s3GetAllSlidesOfSubject(subjectPath)
%This function returns all slides owned by a subject

sectionRootFolder = awsModifyPathForCompetability([subjectPath '/Slides/']);
[sectionNames, sectionPaths] = awsls(sectionRootFolder);
isFolder = cellfun(@(x)(contains(x,'/')),sectionNames);
sectionNames = sectionNames(isFolder);
sectionPaths = sectionPaths(isFolder);

% Remove last '/' from section Names
for i=1:length(sectionNames)
    if sectionNames{i}(end) == '/' || sectionNames{i}(end) == '\'
        sectionNames{i}(end) = [];
    end
end