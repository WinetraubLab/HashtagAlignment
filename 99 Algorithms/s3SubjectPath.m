function p=s3SubjectPath(subject,lib,isCalibrationFolder)
%This function returns the library path in S3 to subject
%Example p=s3SubjectPath('01');
%If subject is empty will return the root folder of all subjects
%isCalibrationFolder - when set to true will return the calibrations folder
%in that lib

if (~exist('lib','var') || isempty(lib))
    %Before releasing a new libary, update lib. Don't forget to search Jenkins
    %file for the same library update
    lib = s3GetAllLibs('last');
end

if ~exist('isCalibrationFolder','var')
    isCalibrationFolder = false;
end

% Figure out prefix
if  length(lib)>=3 && lib(1) == 'L' && (lib(3)=='C' || lib(3) =='M' || lib(3) =='B')
    prefx = lib(3);
    lib = lib(1:2);
else
    prefx = '';
end

p = ['s3://delazerdamatlab/Users/OCTHistologyLibrary/' lib '/'];

if (isCalibrationFolder)
    p = [p '0Calibratoins/' subject '/'];
elseif ~isempty(subject)
    p = [p lib prefx '-' subject '/'];
end

p = awsModifyPathForCompetability(p);