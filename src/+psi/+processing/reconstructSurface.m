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

wrappedPhase = psi.processing.computePSI(imageFiles, selectedIndices);
unwrappedPhase = psi.processing.unwrapPhase(wrappedPhase);
correctedPhase = psi.processing.removeCarrier(unwrappedPhase, ...
    fringeFrequency, processing.referenceRow);
surfaceNm = psi.processing.phaseToSurface(correctedPhase, ...
    processing.wavelengthNm);

result.folder = string(folder);
result.selectedImageNumbers = selectedIndices - 1;
result.phaseShiftsDeg = phaseShifts;
result.fringeFrequency = fringeFrequency;
result.analysisRow = analysisRow;
result.wrappedPhase = wrappedPhase;
result.unwrappedPhase = unwrappedPhase;
result.correctedPhase = correctedPhase;
result.surfaceNm = surfaceNm;
result.processing = processing;

save(fullfile(folder, 'reconstruction.mat'), 'result');
end
