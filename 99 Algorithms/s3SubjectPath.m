function p=s3SubjectPath(subject,lib,isCalibrationFolder)
%This function returns the library path in S3 to subject
%Example p=s3SubjectPath('01');
%If subject is empty will return the root folder of all subjects
%isCalibrationFolder - when set to true will return the calibrations folder
%in that lib

if (~exist('lib','var') || isempty(lib))
    %Before releasing a new libary, update lib. Don't forget to search Jenkins
    %file for the same library update
    lib = 'LD'; 
end

if ~exist('isCalibrationFolder','var')
    isCalibrationFolder = false;
end

p = ['s3://delazerdamatlab/Users/OCTHistologyLibrary/' lib '/'];

if (isCalibrationFolder)
    p = [p 'Calibratoins/' subject '/'];
elseif ~isempty(subject)
    p = [p lib '-' subject '/'];
end

p = awsModifyPathForCompetability(p);