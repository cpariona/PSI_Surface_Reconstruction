function result = reprocessSurface(result, processing)
%REPROCESSSURFACE Reapply phase filtering, 2-D unwrap, spikes and tilt.
% Operates on stored PSI phase/quality; no interferogram files are reread.

filtered = psi.processing.filterWrappedPhase( ...
    result.wrappedPhase, result.qualityMap, processing.filterRadius);
[unwrappedRaw, unwrapMask, unwrapDiagnostics] = ...
    psi.processing.unwrapPhaseQuality(filtered, ...
    result.qualityMap, processing.qualityThreshold);
[unwrapped, spikeMask] = psi.processing.rejectPhaseSpikes( ...
    unwrappedRaw, processing.spikeThresholdRad);
[corrected, plane, coefficients, validMask, referenceMask] = ...
    psi.processing.removeTiltPlane(unwrapped, result.qualityMap, ...
    processing.qualityThreshold, processing.tiltROI);

result.filteredWrappedPhase = filtered;
result.unwrappedPhaseRaw = unwrappedRaw;
result.unwrappedPhase = unwrapped;
result.unwrapMask = unwrapMask;
result.unwrapDiagnostics = unwrapDiagnostics;
result.spikeMask = spikeMask;
result.correctedPhase = corrected;
result.tiltPlane = plane;
result.tiltCoefficients = coefficients;
result.validMask = validMask;
result.referenceMask = referenceMask;
result.surfaceNm = psi.processing.phaseToSurface(corrected, ...
    processing.wavelengthNm);

% Refresh the V2 comparison with identical processing parameters.
if result.v2Available && ~isempty(result.v2WrappedPhase)
    try
        v2Filtered = psi.processing.filterWrappedPhase( ...
            result.v2WrappedPhase, result.v2QualityMap, processing.filterRadius);
        v2Unwrapped = psi.processing.unwrapPhaseQuality( ...
            v2Filtered, result.v2QualityMap, processing.qualityThreshold);
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

result.processing = processing;
result.processingAppliedAt = datetime('now');
save(fullfile(char(result.folder), 'reconstruction.mat'), 'result');
end
