function [subjectPaths,subjectNames] = s3GetAllSubjectsInLib(lib)
%Get path to all subjects in lib, don't specify lib to use the default

if ~exist('lib','var')
    lib = '';
end

% Get all subfolders, each folder is a subject
rootPath = s3SubjectPath('',lib);
[subjectNames, subjectPaths] = awsls(rootPath);
subjectNames = cellfun(@(x)(strrep(x,'/','')),...
    subjectNames,'UniformOutput',false);

% Remove calibration, this is no a subject
isRemove = cellfun(@(sn)(strcmpi(sn,'0calibratoins')),subjectNames) | ...
    cellfun(@(sn)(strcmpi(sn,'0librarystatistics')),subjectNames);

subjectPaths(isRemove) = [];
subjectNames(isRemove) = [];