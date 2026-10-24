function [wrappedPhase, qualityMap, modulation, background] = ...
    computeMultiFramePSI(imageFiles, phaseSteps)
%COMPUTEMULTIFRAMEPSI Least-squares PSI using all acquired interferograms.

phaseSteps = phaseSteps(:);
X = [ones(size(phaseSteps)), cos(phaseSteps), sin(phaseSteps)];

if rank(X) < 3 || cond(X) > 1e6
    error('Phase steps do not provide enough independent information for multi-frame PSI.');
end

P = pinv(X);

firstImage = readGray(imageFiles(1));
background = zeros(size(firstImage));
cosTerm = zeros(size(firstImage));
sinTerm = zeros(size(firstImage));
saturated = false(size(firstImage));

for k = 1:numel(imageFiles)
    image = readGray(imageFiles(k));

    background = background + P(1,k) * image;
    cosTerm = cosTerm + P(2,k) * image;
    sinTerm = sinTerm + P(3,k) * image;
    saturated = saturated | image <= 0 | image >= 255;
end

wrappedPhase = atan2(-sinTerm, cosTerm);
modulation = hypot(cosTerm, sinTerm);
qualityMap = modulation ./ max(abs(background), eps);
qualityMap = min(max(qualityMap, 0), 1);
qualityMap(saturated) = 0;
end

function image = readGray(fileName)
image = imread(fileName);
if ndims(image) == 3
    image = image(:,:,1);
end
image = double(image);
end
