function [wrappedPhase, qualityMap, modulation] = computePSI(imageFiles, selectedIndices)
%COMPUTEPSI Four-step phase-shifting interferometry reconstruction.

I1 = readGray(imageFiles(selectedIndices(1)));
I2 = readGray(imageFiles(selectedIndices(2)));
I3 = readGray(imageFiles(selectedIndices(3)));
I4 = readGray(imageFiles(selectedIndices(4)));

a = I1 - I3;
b = I4 - I2;

wrappedPhase = atan2(a, b);
modulation = hypot(a, b);

meanLevel = I1 + I2 + I3 + I4;
qualityMap = 2 * modulation ./ max(meanLevel, eps);
qualityMap = min(max(qualityMap, 0), 1);

saturated = I1 <= 0 | I1 >= 255 | ...
    I2 <= 0 | I2 >= 255 | ...
    I3 <= 0 | I3 >= 255 | ...
    I4 <= 0 | I4 >= 255;
qualityMap(saturated) = 0;
end

function image = readGray(fileName)
image = imread(fileName);
if ndims(image) == 3
    image = image(:,:,1);
end
image = double(image);
end
