function [slidePaths, slideNames, slidesRootFolder] = s3GetAllSlidesOfSubject(subjectPath)
%This function returns all slides owned by a subject

slidesRootFolder = awsModifyPathForCompetability([subjectPath '/Slides/']);
[slideNames, slidePaths] = awsls(slidesRootFolder);
isFolder = cellfun(@(x)(contains(x,'/')),slideNames);
slideNames = slideNames(isFolder);
slidePaths = slidePaths(isFolder);