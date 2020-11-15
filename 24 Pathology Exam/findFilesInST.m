function isFileInSt = findFilesInST(filePaths,st,additionalFilter)
% Auxilary function returning filePaths index which are of sections to
% search for
% INPUTS:
%   filePaths - cell array of filepaths to match
%   st - st structure of all sections
%   additionalFilter - vector to filter. Sections will be picked out of
%       st.<parameter>(additionalFilter==1), Default is no filter
% OUTPUTS:
%   isFileInSt - logic array, for each file path, is it in the file to
%       search or out?

if (islogical(additionalFilter))
    additionalFilter = find(additionalFilter);
end

subjectNamesToSearchFor = cell(length(additionalFilter),1);
for isFileInSt=1:length(subjectNamesToSearchFor)
    subjectNamesToSearchFor{isFileInSt} = [st.subjectNames{additionalFilter(isFileInSt)} '-' st.sectionNames{additionalFilter(isFileInSt)}];
end

% Remove sections that don't have the very best alignment
isFileInSt = zeros(size(filePaths),'logical');
for i=1:length(isFileInSt)
    isFileInSt(i) = any(cellfun(@(x)(contains(filePaths{i},x)),subjectNamesToSearchFor));
end