function [fringeFrequency, period, row] = estimateFringeFrequency(image, row)
%ESTIMATEFRINGEFREQUENCY Estimate carrier frequency from one image row.

if ischar(image) || isstring(image)
    image = imread(image);
end
if ndims(image) == 3
    image = image(:,:,1);
end

if nargin < 2 || isempty(row)
    row = round(size(image,1)/2);
end

profile = double(image(row,:));
profile = profile - mean(profile);
N = numel(profile);
F = fftshift(fft(profile));
[~, index] = max(abs(F));

fringeFrequency = abs(index - (N/2 + 1));
if fringeFrequency == 0
    error('No fringe carrier frequency was detected.');
end
period = round(N / fringeFrequency);
end
