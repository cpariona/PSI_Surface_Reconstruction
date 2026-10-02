function wrappedPhase = computePSI(imageFiles, selectedIndices)
%COMPUTEPSI Four-step phase-shifting interferometry reconstruction.

I1 = readGray(imageFiles(selectedIndices(1)));
I2 = readGray(imageFiles(selectedIndices(2)));
I3 = readGray(imageFiles(selectedIndices(3)));
I4 = readGray(imageFiles(selectedIndices(4)));

wrappedPhase = atan2((I1 - I3), (I4 - I2));
end

function image = readGray(fileName)
image = imread(fileName);
if ndims(image) == 3
    image = image(:,:,1);
end
image = double(image);
end
