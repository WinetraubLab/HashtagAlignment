function wasSet = setVariblesFromJenkins()
% This function looks in the base workspace for varibles that where set by
% Jenkins. These vaibles have the name "name_" (underscore at the end), and
% set name = name_
% returns true if any varible was set, false otherwise.
% This is a non trivial implementation, but its easier

% Get names of all varibles in parent worksapce
nms = evalin('base','who');

% Get jenkins varibles
isJenkinsInput = cellfun(@(x)(x(end)=='_'),nms);

% Set
nms = nms(isJenkinsInput);
for i=1:length(nms)
    evalin('base',[nms{i}(1:(end-1)) '=' nms{i} ';']);
end

wasSet = length(nms)>0;