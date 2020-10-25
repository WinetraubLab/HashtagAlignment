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
for i=1:length(libraryNames) % Loop over all libraries
    ln = libraryNames{i};
    
    statsPath = [s3SubjectPath('',ln) '0LibraryStatistics/StatusReportBySection.json'];
    if ~awsExist(statsPath,'file')
        error('Cannot find StatusReportBySection.json for library %s. Did you run nightly bild?',ln);
    end
    
    st1 = awsReadJSON(statsPath);
    if isempty(st)
        % First time get fields
        st = st1;
    else
        % Concatinate fields onto the first st
        fn = fieldnames(st);
        for j=1:length(fn) % Loop over all fields  
            if strcmp(fn{j},'notes')
                % 'notes' field shouldn't be concatinate we just use the
                % first one
                continue;
            end
            
            val = st.(fn{j});
            val = val(:);
            
            val1 = st1.(fn{j});
            val1 = val1(:);
            
            % Concatinate
            st.(fn{j}) = [val; val1];
        end
    end
end
    
    