function p=s3SubjectPath(subject)
%This function returns the library path in S3 to subject
%Example p=s3SubjectPath('01');

%Before releasing a new libary, update lib. Don't forget to search Jenkins
%file for the same library update
lib = 'LD'; 

p = ['s3://delazerdamatlab/Users/OCTHistologyLibrary/' lib '/' lib '-' subject '/'];