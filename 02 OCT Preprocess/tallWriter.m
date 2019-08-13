function tallWriter (info, data)
if (info.PartitionIndex ~= 1) || (info.BlockIndexInPartition ~= 1)
    error('info.PartitionIndex = %d, info.BlockIndexInPartition = %d - both should be 1',...
        info.PartitionIndex,info.BlockIndexInPartition);
end
ff = strrep(info.RequiredFilePattern,'*','1');%Remove required pattern, its easier that way
filename1 = sprintf('%s/%s',info.RequiredLocation, ff);
%filename1 = info.SuggestedFilename;
yOCT2Mat(data{:}, filename1);
end