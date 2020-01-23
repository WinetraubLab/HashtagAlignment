function stackConfig = scDeleteIterationsFromStackConfig(stackConfig, iterationsToDelete)
% This function deletes iterations from stack config. enter which
% iterations you would like to delete

%% Input Checks
if (length(iterationsToDelete) > 1)
    error('Cannot delete more than one iteration at a time');
end

lastIteration = max(stackConfig.sections.iterations);
if iterationsToDelete ~= lastIteration
    error('Can only delete last iteration');
end

%% Delete

% Delete iterations from histology instructions.
stackConfig.histologyInstructions.iterations(iterationsToDelete) = [];

% Delete slides associated with those iterations
slidesToDeleteI = zeros(size(stackConfig.sections.iterations),'logical');
for i=1:length(iterationsToDelete)
    slidesToDeleteI = slidesToDeleteI | ...
        stackConfig.sections.iterations == iterationsToDelete(i);
end
stackConfig.sections.iterations(slidesToDeleteI) = [];
stackConfig.sections.names(slidesToDeleteI) = [];
