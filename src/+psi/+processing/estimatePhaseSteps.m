function [phaseSteps, fringeFrequency, row] = estimatePhaseSteps(imageFiles, row)
%ESTIMATEPHASESTEPS Estimate global phase steps from the fringe carrier.

[fringeFrequency, ~, row] = ...
    psi.processing.estimateFringeFrequency(imageFiles(1), row);

phaseSteps = zeros(numel(imageFiles), 1);
carrierIndex = fringeFrequency + 1;

for k = 1:numel(imageFiles)
    image = imread(imageFiles(k));
    if ndims(image) == 3
        image = image(:,:,1);
    end

    profile = double(image(row,:));
    profile = profile - mean(profile);
    spectrum = fft(profile);
    phaseSteps(k) = angle(spectrum(carrierIndex));
end

phaseSteps = unwrap(phaseSteps);
phaseSteps = phaseSteps - phaseSteps(1);
end
