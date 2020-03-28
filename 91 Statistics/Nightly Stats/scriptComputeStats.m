% This script computs stats for the following libraries

libraryNames = {'LF','LE','LD','LC'};

%% Compute section status report
for i=1:length(libraryNames)
    ln = libraryNames{i};
    fprintf('%s Processing %s\n',datestr(datetime),ln);
    statsPath = [s3SubjectPath('',ln) '0LibraryStatistics/'];
    
    % Generate status
    fprintf('%s Building Stats Report\n',datestr(datetime));
    st = generateStatusReportByLibrary(ln);
    
    % Write it to AWS
    awsWriteJSON(st,[statsPath '/StatusReportBySection.json']);
    
    % Upload to cloud
    fprintf('%s Submitting to Google Sheets\n',datestr(datetime));
    submitStatusReportToGoogle(st);
end
fprintf('%s Done!\n',datestr(datetime));



