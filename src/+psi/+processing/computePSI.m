function wrappedPhase = computePSI(imageFiles, selectedIndices)
%COMPUTEPSI Four-step phase-shifting interferometry reconstruction.

I1 = double(imread(imageFiles(selectedIndices(1))));
I2 = double(imread(imageFiles(selectedIndices(2))));
I3 = double(imread(imageFiles(selectedIndices(3))));
I4 = double(imread(imageFiles(selectedIndices(4))));

wrappedPhase = atan2((I1 - I3), (I4 - I2));
end
