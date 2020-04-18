function changeFolderName(subjectPath)
% This function renames a folder
% Written at April 17, 2020.
%% Input checks

if ~exist('subjectPath','var')
    subjectPath = s3SubjectPath('01');
end

oldFolderName = awsModifyPathForCompetability([subjectPath '\Log\14 Image Pair Quality Control\']);
newFolderName = awsModifyPathForCompetability([subjectPath '\Log\14 Quality Control and Post Processing\']);

if awsExist(oldFolderName,'dir')
    disp('Copy');
    awsCopyFileFolder(oldFolderName,newFolderName);
    awsRmDir(oldFolderName);
end

