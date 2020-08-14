function [ii,s] = findSectionInStatusReport(s,subjectName,sectionName)
% Returns section's index in the status report s.
% If s is a cell or a string, will first load status report than search for
% the secitoin in it

%% Input checks
if iscell(s) || ischar(s)
    s = loadStatusReportByLibrary(s);
end

%% Find index 
i1 = cellfun(@(x)(strcmpi(x,subjectName)),s.subjectNames);
i2 = cellfun(@(x)(strcmpi(x,sectionName)),s.sectionNames);

ii = find(i1 & i2);
