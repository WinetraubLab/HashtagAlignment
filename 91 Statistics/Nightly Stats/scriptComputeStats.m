% This script computs stats for the following libraries

libraryNames = {'LF','LE','LD'};
isSubmitStast = false;

%% Compute section status report
disp('Building Stats Report');
for i=1:length(libraryNames)
    ln = libraryNames{i};
    disp(ln);
    statsPath = [s3SubjectPath('',ln) '0LibraryStatistics/'];
    
    % Generate status
    st = generateStatusReportByLibrary(ln);
    
    % Write it to AWS
    awsWriteJSON(st,[statsPath '/StatusReportBySection.json']);
    
    % Upload to cloud
    submitStatusReportToGoogle(st);
end

%% Submit stats to google spreadsheet if needed
if ~isSubmitStast
    return;
end
disp('Submitting to Cloud');


