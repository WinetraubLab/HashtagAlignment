% This script computs stats for the following libraries

libraryNames = {'LF','LE'};
isSubmitStast = true;

%% Compute section status report
disp('Building Stats Report');
for i=1:length(libraryNames)
    ln = libraryNames{i};
    disp(ln);
    statsPath = [s3SubjectPath('',ln) '0LibraryStatistics/'];
    
    st = generateStatusReportByLibrary(ln);
    
    awsWriteJSON(st,[statsPath '/StatusReportBySection.json']);
end

%% Submit stats to google spreadsheet if needed
if ~isSubmitStast
    return;
end
disp('Submitting to Cloud');


