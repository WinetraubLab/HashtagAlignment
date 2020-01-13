function stackConfig = scDeleteIterationsFromStackConfig(stackConfig, iterationsToDelete)
% This function deletes iterations from stack config. enter which
% iterations you would like to delete

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
