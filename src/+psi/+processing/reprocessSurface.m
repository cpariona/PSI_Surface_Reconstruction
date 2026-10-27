function result = reprocessSurface(result, processing)
%REPROCESSSURFACE Recalculate only stages affected by changed parameters.
% The PSI wrapped phase is cached; V2 comparison is optional, not automatic.

totalClock = tic;
old = struct();
if isfield(result, 'processing')
    old = result.processing;
end

sameFilter = isfield(old, 'filterRadius') && ...
    isequal(old.filterRadius, processing.filterRadius);
sameQuality = isfield(old, 'qualityThreshold') && ...
    isequal(old.qualityThreshold, processing.qualityThreshold);
sameSpike = isfield(old, 'spikeThresholdRad') && ...
    isequal(old.spikeThresholdRad, processing.spikeThresholdRad);
sameROI = isfield(old, 'tiltROI') && isequaln(old.tiltROI, processing.tiltROI);
sameWavelength = isfield(old, 'wavelengthNm') && ...
    isequal(old.wavelengthNm, processing.wavelengthNm);

runFilter = ~sameFilter || ~isfield(result, 'filteredWrappedPhase');
runUnwrap = runFilter || ~sameQuality || ~isfield(result, 'unwrappedPhaseRaw');
runSpikes = runUnwrap || ~sameSpike || ~isfield(result, 'spikeMask');
runTilt = runSpikes || ~sameROI || ~sameWavelength || ...
    ~isfield(result, 'correctedPhase');

timings = struct('filter', 0, 'unwrap', 0, 'spikes', 0, 'tilt', 0, 'save', 0);
ran = struct('filter', runFilter, 'unwrap', runUnwrap, ...
    'spikes', runSpikes, 'tilt', runTilt);

if runFilter
    clock = tic;
    result.filteredWrappedPhase = psi.processing.filterWrappedPhase( ...
        result.wrappedPhase, result.qualityMap, processing.filterRadius);
    timings.filter = toc(clock);
end
if runUnwrap
    clock = tic;
    [result.unwrappedPhaseRaw, result.unwrapMask, result.unwrapDiagnostics] = ...
        psi.processing.unwrapPhaseQuality(result.filteredWrappedPhase, ...
        result.qualityMap, processing.qualityThreshold);
    timings.unwrap = toc(clock);
end
if runSpikes
    clock = tic;
    [result.unwrappedPhase, result.spikeMask] = ...
        psi.processing.rejectPhaseSpikes(result.unwrappedPhaseRaw, ...
        processing.spikeThresholdRad);
    timings.spikes = toc(clock);
end
if runTilt
    clock = tic;
    [result.correctedPhase, result.tiltPlane, result.tiltCoefficients, ...
        result.validMask, result.referenceMask] = ...
        psi.processing.removeTiltPlane(result.unwrappedPhase, ...
        result.qualityMap, processing.qualityThreshold, processing.tiltROI);
    result.surfaceNm = psi.processing.phaseToSurface( ...
        result.correctedPhase, processing.wavelengthNm);
    timings.tilt = toc(clock);
end

% The costly four-frame comparison runs only when explicitly enabled.
compareV2 = isfield(processing, 'computeV2Comparison') && ...
    processing.computeV2Comparison;
if compareV2 && isfield(result, 'v2Available') && result.v2Available
    if runFilter || runUnwrap || runSpikes || runTilt || ...
            isempty(result.v2SurfaceNm)
        try
            v2Filtered = psi.processing.filterWrappedPhase( ...
                result.v2WrappedPhase, result.v2QualityMap, ...
                processing.filterRadius);
            v2Unwrapped = psi.processing.unwrapPhaseQuality( ...
                v2Filtered, result.v2QualityMap, ...
                processing.qualityThreshold);
            [v2Unwrapped, ~] = psi.processing.rejectPhaseSpikes( ...
                v2Unwrapped, processing.spikeThresholdRad);
            [v2Corrected, ~] = psi.processing.removeTiltPlane( ...
                v2Unwrapped, result.v2QualityMap, ...
                processing.qualityThreshold, processing.tiltROI);
            result.v2UnwrappedPhase = v2Unwrapped;
            result.v2SurfaceNm = psi.processing.phaseToSurface( ...
                v2Corrected, processing.wavelengthNm);
            result.v2Error = "";
        catch ME
            result.v2UnwrappedPhase = [];
            result.v2SurfaceNm = [];
            result.v2Error = string(ME.message);
        end
    end
elseif isfield(result, 'v2Available') && result.v2Available && ...
        (runFilter || runUnwrap || runSpikes || runTilt)
    result.v2UnwrappedPhase = [];
    result.v2SurfaceNm = [];
    result.v2Error = "V2 comparison stale (enable computeV2Comparison to recompute).";
end

result.processing = processing;
result.processingAppliedAt = datetime('now');
timings.compute = toc(totalClock);
result.processingTimes = timings;
result.processingStages = ran;
clock = tic;
outputFile = fullfile(char(result.folder), 'reconstruction.mat');
if isfield(result.processing, 'fastSave') && result.processing.fastSave
    save(outputFile, 'result', '-nocompression');
else
    save(outputFile, 'result');
end
result.processingTimes.save = toc(clock);
result.processingTimes.total = toc(totalClock);
end
