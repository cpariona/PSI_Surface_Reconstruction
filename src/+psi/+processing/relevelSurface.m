function result = relevelSurface(result, tiltROI)
%RELEVELSURFACE Refit tilt from the selected ROI without rerunning PSI.

started = tic;

[corrected, plane, coefficients, validMask, referenceMask] = ...
    psi.processing.removeTiltPlane(result.unwrappedPhase, ...
    result.qualityMap, result.processing.qualityThreshold, tiltROI);

result.correctedPhase = corrected;
result.tiltPlane = plane;
result.tiltCoefficients = coefficients;
result.validMask = validMask;
result.referenceMask = referenceMask;
polarity = 1;
if isfield(result, 'heightPolarity')
    polarity = result.heightPolarity;
end
result.surfaceNm = polarity * psi.processing.phaseToSurface( ...
    corrected, result.processing.wavelengthNm);
result.processing.tiltROI = tiltROI;
result.processingAppliedAt = datetime('now');

if result.v2Available && ~isempty(result.v2UnwrappedPhase)
    try
        [v2Corrected, ~] = psi.processing.removeTiltPlane( ...
            result.v2UnwrappedPhase, result.v2QualityMap, ...
            result.processing.qualityThreshold, tiltROI);
        result.v2SurfaceNm = psi.processing.phaseToSurface( ...
            v2Corrected, result.processing.wavelengthNm);
        result.v2Error = "";
    catch ME
        % An invalid V2 reference must not discard the valid V3 leveling.
        result.v2SurfaceNm = [];
        result.v2Error = string(ME.message);
    end
end

result.processingTimes = struct('compute', toc(started), ...
    'filter', 0, 'unwrap', 0, 'spikes', 0, 'tilt', toc(started), ...
    'save', 0);
result.processingStages = struct('filter', false, 'unwrap', false, ...
    'spikes', false, 'tilt', true);
outputFile = fullfile(char(result.folder), 'reconstruction.mat');
saveClock = tic;
if isfield(result.processing, 'fastSave') && result.processing.fastSave
    save(outputFile, 'result', '-nocompression');
else
    save(outputFile, 'result');
end
result.processingTimes.save = toc(saveClock);
result.processingTimes.total = toc(started);
end
