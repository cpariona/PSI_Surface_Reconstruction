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

% Determine height sign without altering the wrapped-phase or unwrap results.
polarityOverride = [];
if isfield(processing, 'heightPolarity')
    polarityOverride = processing.heightPolarity;
end
if isfield(result, 'phaseStepsDeg') && ~isempty(result.phaseStepsDeg)
    [polarity, fringeDirection, fringeMotion] = ...
        psi.processing.inferHeightPolarity( ...
        result.phaseStepsDeg * pi/180, polarityOverride);
    result.fringeDirection = fringeDirection;
    result.fringeMotion = fringeMotion;
elseif ~isempty(polarityOverride)
    if ~isnumeric(polarityOverride) || ~isscalar(polarityOverride) || ...
            ~ismember(polarityOverride, [-1, 1])
        error('Height polarity override must be +1 or -1.');
    end
    polarity = polarityOverride;
elseif isfield(result, 'heightPolarity')
    polarity = result.heightPolarity;
else
    % Backwards compatibility for synthetic or previously cached PSI data.
    polarity = 1;
end
samePolarity = isfield(result, 'heightPolarity') && ...
    isequal(result.heightPolarity, polarity);

runFilter = ~sameFilter || ~isfield(result, 'filteredWrappedPhase');
runUnwrap = runFilter || ~sameQuality || ~isfield(result, 'unwrappedPhaseRaw');
runSpikes = runUnwrap || ~sameSpike || ~isfield(result, 'spikeMask');
runTilt = runSpikes || ~sameROI || ~isfield(result, 'correctedPhase');
runHeight = runTilt || ~sameWavelength || ~samePolarity || ...
    ~isfield(result, 'surfaceNm');

timings = struct('filter', 0, 'unwrap', 0, 'spikes', 0, 'tilt', 0, 'save', 0);
ran = struct('filter', runFilter, 'unwrap', runUnwrap, ...
    'spikes', runSpikes, 'tilt', runTilt, 'height', runHeight);

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
    timings.tilt = toc(clock);
end
if runHeight
    % Reflective PSI: flip height polarity only after phase unwrapping/tilt.
    result.surfaceNm = polarity * psi.processing.phaseToSurface( ...
        result.correctedPhase, processing.wavelengthNm);
end
result.heightPolarity = polarity;

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
