function p=s3SubjectPath(subject,lib)
%This function returns the library path in S3 to subject
%Example p=s3SubjectPath('01');
%If subject is empty will return the root folder of all subjects

if (~exist('lib','var') || isempty(lib))
    %Before releasing a new libary, update lib. Don't forget to search Jenkins
    %file for the same library update
    lib = 'LD'; 
end

p = ['s3://delazerdamatlab/Users/OCTHistologyLibrary/' lib '/'];
if ~isempty(subject)
    p = [p lib '-' subject '/'];
end