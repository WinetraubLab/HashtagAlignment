function phases = splitDataToPhases(subjectNames)
% INPUTS:
%   subjectNames - cell array with subject names
%
% OUTPUTS:
%   phases - can be 0 train, 1 test

% Subject in training set
% LC,LD,LE,LF, Begining of LG - chronologically these are the first samples.
% LG-4x and LG-5x seems to fail often, so we add them to training set.

subjectsInTestingSet = { ...
    ... Good samples for figures:
    'LE-03','LF-01','LG-03','LG-19', 'LG-44', ... 
    ... Samples from unknown area:
    'LD-11','LG-07', ...
    ... Bad histology section but still useable as test:
    'LG-02', ...
    ... These samples are been reviewed for quality still:
    ...'LG-18', ...
    ... New Samples Coming in, add them to test set:
    'LG-2','LG-3','LG-6','LG-7','LG-8','LG-9','LGC', ...
    'LH' ...
    }; 

%% Input checks
if ~iscell(subjectNames)
    subjectNames = {subjectNames};
end

%% Do work
phases = zeros(size(subjectNames),'logical');
for i=1:length(phases)
    isInTesting = cellfun(@(x)(contains(subjectNames{i},x)),subjectsInTestingSet);
    if any(isInTesting)
        phases(i) = 1;
    else
        phases(i) = 0;
    end
end
