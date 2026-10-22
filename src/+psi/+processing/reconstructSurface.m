function result = reconstructSurface(folder, processing)
%RECONSTRUCTSURFACE Reconstruct surface from an acquired interferogram scan.

files = dir(fullfile(folder, 'image*.bmp'));
imageNumbers = zeros(size(files));
for k = 1:numel(files)
    token = regexp(files(k).name, 'image(\d+)\.bmp', 'tokens', 'once');
    imageNumbers(k) = str2double(token{1});
end
[~, order] = sort(imageNumbers);
files = files(order);
imageFiles = string(fullfile({files.folder}, {files.name}));

[selectedIndices, fringeFrequency, phaseShifts, analysisRow] = ...
    psi.processing.selectPhaseFrames(imageFiles, processing.analysisRow, ...
    processing.phaseStepDeg, processing.phaseToleranceDeg);

[wrappedPhase, qualityMap, modulation] = ...
    psi.processing.computePSI(imageFiles, selectedIndices);

% Legacy reconstruction retained for direct comparison.
legacyUnwrappedPhase = psi.processing.unwrapPhase(wrappedPhase);
legacyCorrectedPhase = psi.processing.removeCarrier(legacyUnwrappedPhase, ...
    fringeFrequency, processing.referenceRow);
legacySurfaceNm = psi.processing.phaseToSurface(legacyCorrectedPhase, ...
    processing.wavelengthNm);

% V2 reconstruction.
filteredWrappedPhase = psi.processing.filterWrappedPhase( ...
    wrappedPhase, qualityMap, processing.filterRadius);
unwrappedPhase = psi.processing.unwrapPhaseQuality( ...
    filteredWrappedPhase, qualityMap, processing.qualityThreshold);
[correctedPhase, tiltPlane, tiltCoefficients, validMask] = ...
    psi.processing.removeTiltPlane(unwrappedPhase, qualityMap, ...
    processing.qualityThreshold);
surfaceNm = psi.processing.phaseToSurface(correctedPhase, ...
    processing.wavelengthNm);

result.folder = string(folder);
result.version = "v2";
result.selectedImageNumbers = selectedIndices - 1;
result.phaseShiftsDeg = phaseShifts;
result.fringeFrequency = fringeFrequency;
result.analysisRow = analysisRow;

result.wrappedPhase = wrappedPhase;
result.qualityMap = qualityMap;
result.modulation = modulation;
result.filteredWrappedPhase = filteredWrappedPhase;
result.unwrappedPhase = unwrappedPhase;
result.tiltPlane = tiltPlane;
result.tiltCoefficients = tiltCoefficients;
result.validMask = validMask;
result.correctedPhase = correctedPhase;
result.surfaceNm = surfaceNm;

result.legacyUnwrappedPhase = legacyUnwrappedPhase;
result.legacyCorrectedPhase = legacyCorrectedPhase;
result.legacySurfaceNm = legacySurfaceNm;
result.processing = processing;

save(fullfile(folder, 'reconstruction.mat'), 'result');
end
