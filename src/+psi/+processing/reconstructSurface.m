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

if numel(imageFiles) < 3
    error('At least three interferograms are required for multi-frame PSI.');
end

% V3: estimate the actual global phase of every frame and use all images.
[phaseSteps, fringeFrequency, analysisRow] = ...
    psi.processing.estimatePhaseSteps(imageFiles, processing.analysisRow);
[wrappedPhase, qualityMap, modulation, background] = ...
    psi.processing.computeMultiFramePSI(imageFiles, phaseSteps);

filteredWrappedPhase = psi.processing.filterWrappedPhase( ...
    wrappedPhase, qualityMap, processing.filterRadius);
[unwrappedPhaseRaw, unwrapMask, unwrapDiagnostics] = ...
    psi.processing.unwrapPhaseQuality(filteredWrappedPhase, ...
    qualityMap, processing.qualityThreshold);
[unwrappedPhase, spikeMask] = psi.processing.rejectPhaseSpikes( ...
    unwrappedPhaseRaw, processing.spikeThresholdRad);
[correctedPhase, tiltPlane, tiltCoefficients, validMask, referenceMask] = ...
    psi.processing.removeTiltPlane(unwrappedPhase, qualityMap, ...
    processing.qualityThreshold, processing.tiltROI);
surfaceNm = psi.processing.phaseToSurface(correctedPhase, ...
    processing.wavelengthNm);

% Keep V2 and legacy outputs when four ~90 degree frames can be found.
v2Available = false;
v2Error = "";
selectedIndices = [];
selectedPhaseShifts = [];
v2SurfaceNm = [];
legacySurfaceNm = [];
v2UnwrappedPhase = [];

try
    [selectedIndices, ~, selectedPhaseShifts] = ...
        psi.processing.selectPhaseFrames(imageFiles, analysisRow, ...
        processing.phaseStepDeg, processing.phaseToleranceDeg);

    [v2WrappedPhase, v2QualityMap] = ...
        psi.processing.computePSI(imageFiles, selectedIndices);
    v2FilteredPhase = psi.processing.filterWrappedPhase( ...
        v2WrappedPhase, v2QualityMap, processing.filterRadius);
    v2UnwrappedPhase = psi.processing.unwrapPhaseQuality( ...
        v2FilteredPhase, v2QualityMap, processing.qualityThreshold);
    [v2UnwrappedPhase, ~] = psi.processing.rejectPhaseSpikes( ...
        v2UnwrappedPhase, processing.spikeThresholdRad);
    [v2CorrectedPhase, ~, ~, ~] = psi.processing.removeTiltPlane( ...
        v2UnwrappedPhase, v2QualityMap, ...
        processing.qualityThreshold, processing.tiltROI);
    v2SurfaceNm = psi.processing.phaseToSurface(v2CorrectedPhase, ...
        processing.wavelengthNm);

    legacyUnwrappedPhase = psi.processing.unwrapPhase(v2WrappedPhase);
    legacyCorrectedPhase = psi.processing.removeCarrier( ...
        legacyUnwrappedPhase, fringeFrequency, processing.referenceRow);
    legacySurfaceNm = psi.processing.phaseToSurface( ...
        legacyCorrectedPhase, processing.wavelengthNm);

    v2Available = true;
catch ME
    v2Error = string(ME.message);
end

result.folder = string(folder);
result.version = "v3";
result.imageCount = numel(imageFiles);
result.phaseStepsDeg = phaseSteps * 180/pi;
result.phaseSpanDeg = (max(phaseSteps) - min(phaseSteps)) * 180/pi;
result.fringeFrequency = fringeFrequency;
result.analysisRow = analysisRow;

result.wrappedPhase = wrappedPhase;
result.qualityMap = qualityMap;
result.modulation = modulation;
result.background = background;
result.filteredWrappedPhase = filteredWrappedPhase;
result.unwrappedPhase = unwrappedPhase;
result.unwrappedPhaseRaw = unwrappedPhaseRaw;
result.unwrapMask = unwrapMask;
result.unwrapDiagnostics = unwrapDiagnostics;
result.spikeMask = spikeMask;
result.referenceMask = referenceMask;
result.tiltPlane = tiltPlane;
result.tiltCoefficients = tiltCoefficients;
result.validMask = validMask;
result.correctedPhase = correctedPhase;
result.surfaceNm = surfaceNm;

result.v2Available = v2Available;
result.v2SelectedImageNumbers = selectedIndices - 1;
result.v2PhaseShiftsDeg = selectedPhaseShifts;
result.v2SurfaceNm = v2SurfaceNm;
result.v2UnwrappedPhase = v2UnwrappedPhase;
if v2Available
    result.v2QualityMap = v2QualityMap;
else
    result.v2QualityMap = [];
end
result.legacySurfaceNm = legacySurfaceNm;
result.v2Error = v2Error;
result.processing = processing;

save(fullfile(folder, 'reconstruction.mat'), 'result');
end
