function lib = s3GetAllLibs (w)
% Get names of all active libs
% Set w='last' to get only the latest lib

lib = {'LC','LD','LE','LF','LG','LH','LI','LJ'};

if exist('w','var') && strcmp(w,'last')
    lib = lib{end};
end