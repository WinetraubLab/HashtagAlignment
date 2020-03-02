function st = loadStatusReportByLibrary(libraryNames)
% Loads status report generated for each library (from nightly blild) and
% loads it to one st. see generateStatusReportByLibrary for full information
%
% INPUTS:
%   libraryNames - can be a string or a cell containing library names. 
%       Examples: 'LA' or {'LA','LB'}
% OUTPUTS:
%   st - see generateStatusReportByLibrary.

%% Input check
if ~iscell(libraryNames)
    libraryNames = {libraryNames};
end


%% Load and concatinate
st = [];
for i=1:length(libraryNames)
    ln = libraryNames{i};
    
    statsPath = [s3SubjectPath('',ln) '0LibraryStatistics/StatusReportBySection.json'];
    if ~awsExist(statsPath,'file')
        error('Cannot find StatusReportBySection.json for library %s. Did you run nightly bild?',ln);
    end
    
    st1 = awsReadJSON(statsPath);
    if isempty(st)
        st = st1;
    else
        fn = fieldnames(a);
        for j=1:length(fn)            
            val = st.(fn{i});
            val = val(:);
            
            val1 = st1.(fn{i});
            val1 = val1(:);
            
            st.(fn{i}) = [val; val1];
        end
    end
end
    
    