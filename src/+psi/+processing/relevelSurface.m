function result = relevelSurface(result, tiltROI)
%RELEVELSURFACE Refit tilt using a new flat reference ROI without rerunning PSI.

[corrected, plane, coefficients, validMask, referenceMask] = ...
    psi.processing.removeTiltPlane(result.unwrappedPhase, ...
    result.qualityMap, result.processing.qualityThreshold, tiltROI);

result.correctedPhase = corrected;
result.tiltPlane = plane;
result.tiltCoefficients = coefficients;
result.validMask = validMask;
result.referenceMask = referenceMask;
result.surfaceNm = psi.processing.phaseToSurface( ...
    corrected, result.processing.wavelengthNm);
result.processing.tiltROI = tiltROI;

if result.v2Available && ~isempty(result.v2UnwrappedPhase)
    [v2Corrected, ~] = psi.processing.removeTiltPlane( ...
        result.v2UnwrappedPhase, result.v2QualityMap, ...
        result.processing.qualityThreshold, tiltROI);
    result.v2SurfaceNm = psi.processing.phaseToSurface( ...
        v2Corrected, result.processing.wavelengthNm);
end

save(fullfile(char(result.folder), 'reconstruction.mat'), 'result');
end
