function [subjectPaths,subjectNames] = s3GetAllSubjectsInLib(lib)
% Get path to all subjects in lib, don't specify lib to use the default
% If lib is cell, will get all subjects in all libs described in the cells.

if ~exist('lib','var')
    lib = '';
end

%% Nested calls
if iscell(lib)
    subjectPaths = [];
    subjectNames = [];
    
    for i=1:length(lib)
        [p,n] = s3GetAllSubjectsInLib(lib{i});
        subjectPaths = [subjectPaths p];
        subjectNames = [subjectNames n];
    end
    return;
end

%% Regular call
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

% Make sure subject Paths and names are columns
subjectPaths = subjectPaths(:);
subjectNames = subjectNames(:);