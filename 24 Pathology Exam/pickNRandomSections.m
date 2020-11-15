function isUseSection = pickNRandomSections(st,cap,additionalFilter)
% This section takes st data structure and picks sections at random.
% Will try to get as much diversity as possible.
% INPUTS:
%   st - st data structure
%   cap - how many files to get
%   additionalFilter - vector to filter. Sections will be picked out of
%       st.<parameter>(additionalFilter==1), Default is no filter
% OUTPUTS:
%   isUseSection - array set to 1 for each st section to use.

%% Input checks
if ~exist('additionalFilter','var')
    % All pass
    additionalFilter = ones(size(st.subjectNames),'logical');
end

%% Initialize by randomizing
iToExamine = find(additionalFilter == 1);
iToExamine = iToExamine(randperm(length(iToExamine)));

isUseSection = zeros(size(st.subjectNames),'logical');

if(length(iToExamine) < cap)
    warning('Cap requested is longer then the avilable sections in st, reducing cap');
    isUseSection(iToExamine) = true;
    return;
end

%% Trim down sections until we get the number we need
n = length(iToExamine)-cap; % Number of sections needed to trim down
for i=1:n
    % Compute which subjects has maximal number of sections
    [u, ~, ui] = unique(st.subjectNames(iToExamine),'stable');
    ul = zeros(size(u));
    for j=1:length(u)
        ul(j) = sum(ui == j);
    end
    
    % Find subject with max number of sections
    s = u{find(ul == max(ul),1,'first')};
    
    % Remove one section from that subject
    iToRemove = find(cellfun(@(x)(strcmp(s,x)),st.subjectNames(iToExamine)),1,'first');
    iToExamine(iToRemove) = [];
end

%% Finalize
isUseSection(iToExamine) = true;
