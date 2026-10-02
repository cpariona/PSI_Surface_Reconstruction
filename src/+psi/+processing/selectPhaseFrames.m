function [selectedIndices, fringeFrequency, phaseShifts, row] = ...
    selectPhaseFrames(imageFiles, row, targetPhaseDeg, toleranceDeg)
%SELECTPHASEFRAMES Select four interferograms separated by ~90 degrees.

[fringeFrequency, period, row] = ...
    psi.processing.estimateFringeFrequency(imageFiles(1), row);

firstImage = imread(imageFiles(1));
if ndims(firstImage) == 3
    firstImage = firstImage(:,:,1);
end
Ncol = size(firstImage,2);
lags = -(Ncol-1):(Ncol-1);

selectedIndices = nan(1,4);
phaseShifts = zeros(1,4);
selectedIndices(1) = 1;
current = 1;

for n = 2:4
    baseImage = imread(imageFiles(current));
    if ndims(baseImage) == 3
        baseImage = baseImage(:,:,1);
    end
    baseProfile = double(baseImage(row,:));
    baseProfile = baseProfile - mean(baseProfile);

    for candidate = current+1:numel(imageFiles)
        candidateImage = imread(imageFiles(candidate));
        if ndims(candidateImage) == 3
            candidateImage = candidateImage(:,:,1);
        end
        candidateProfile = double(candidateImage(row,:));
        candidateProfile = candidateProfile - mean(candidateProfile);

        correlation = conv(baseProfile, fliplr(candidateProfile), 'full');
        correlation = correlation / (norm(baseProfile) * norm(candidateProfile));
        [~, index] = max(correlation);
        phaseShift = lags(index) * 360 / period;

        if abs(targetPhaseDeg - abs(phaseShift)) <= toleranceDeg
            selectedIndices(n) = candidate;
            phaseShifts(n) = phaseShift;
            current = candidate;
            break
        end
    end

    if isnan(selectedIndices(n))
        error('Could not find four interferograms with the requested phase spacing.');
    end
end
end
