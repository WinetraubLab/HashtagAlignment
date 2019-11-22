function [subjectPaths,subjectNames] = s3GetAllSubjectsInLib(lib)
%Get path to all subjects in lib, don't specify lib to use the default

if ~exist('lib','var')
    lib = '';
end

rootPath = s3SubjectPath('',lib);
[subjectNames, subjectPaths] = awsls(rootPath);
subjectNames = cellfun(@(x)(strrep(x,'/','')),...
    subjectNames,'UniformOutput',false);