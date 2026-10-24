function result = reconstructSurface(folder, processing)
%RECONSTRUCTSURFACE Compute multi-frame PSI and reconstruct the surface.

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

[phaseSteps, fringeFrequency, analysisRow] = ...
    psi.processing.estimatePhaseSteps(imageFiles, processing.analysisRow);
[wrappedPhase, qualityMap, modulation, background] = ...
    psi.processing.computeMultiFramePSI(imageFiles, phaseSteps);

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

% Legacy and four-frame input are cached only when selection is possible.
result.v2Available = false;
result.v2Error = "";
result.v2SelectedImageNumbers = [];
result.v2PhaseShiftsDeg = [];
result.v2WrappedPhase = [];
result.v2QualityMap = [];
result.v2UnwrappedPhase = [];
result.v2SurfaceNm = [];
result.legacySurfaceNm = [];

try
    [selectedIndices, ~, phaseShifts] = ...
        psi.processing.selectPhaseFrames(imageFiles, analysisRow, ...
        processing.phaseStepDeg, processing.phaseToleranceDeg);
    [v2Phase, v2Quality] = psi.processing.computePSI( ...
        imageFiles, selectedIndices);
    legacyUnwrapped = psi.processing.unwrapPhase(v2Phase);
    legacyCorrected = psi.processing.removeCarrier( ...
        legacyUnwrapped, fringeFrequency, processing.referenceRow);

    result.v2Available = true;
    result.v2SelectedImageNumbers = imageNumbers(order(selectedIndices));
    result.v2PhaseShiftsDeg = phaseShifts;
    result.v2WrappedPhase = v2Phase;
    result.v2QualityMap = v2Quality;
    result.legacySurfaceNm = psi.processing.phaseToSurface( ...
        legacyCorrected, processing.wavelengthNm);
catch ME
    result.v2Error = string(ME.message);
end

% Same backend for initial reconstruction and later Apply processing.
result = psi.processing.reprocessSurface(result, processing);
end
