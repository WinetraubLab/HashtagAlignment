% This script computs stats for the following libraries

libraryNames = {'LF','LE','LD','LC'};

%% Compute section status report
for i=1:length(libraryNames)
    ln = libraryNames{i};
    disp(ln);
    statsPath = [s3SubjectPath('',ln) '0LibraryStatistics/'];
    
    % Generate status
    disp('Building Stats Report');
    st = generateStatusReportByLibrary(ln);
    
    % Write it to AWS
    awsWriteJSON(st,[statsPath '/StatusReportBySection.json']);
    
    % Upload to cloud
    disp('Submitting to Cloud');
    submitStatusReportToGoogle(st);
end




