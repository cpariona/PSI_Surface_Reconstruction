function [correctedPhase, plane, coefficients, validMask, referenceMask] = ...
    removeTiltPlane(unwrappedPhase, qualityMap, threshold, roi)
%REMOVETILTPLANE Fit a robust weighted plane on a flat reference region.
% ROI is [x, y, width, height] in pixel coordinates; [] means full field.

if nargin < 4
    roi = [];
end

[rows, cols] = size(unwrappedPhase);
[x, y] = meshgrid(1:cols, 1:rows);
validMask = isfinite(unwrappedPhase) & isfinite(qualityMap) & ...
    qualityMap > 0 & qualityMap >= threshold;

referenceMask = validMask;
if ~isempty(roi)
    if numel(roi) ~= 4 || any(~isfinite(roi)) || any(roi(3:4) <= 0)
        error('Tilt reference ROI must be [x y width height] with positive size.');
    end
    referenceMask = referenceMask & ...
        x >= roi(1) & x <= roi(1)+roi(3) & ...
        y >= roi(2) & y <= roi(2)+roi(4);
end

if nnz(referenceMask) < 25
    error('Tilt reference has fewer than 25 reliable pixels. Choose a larger flat ROI.');
end

x0 = mean(x(referenceMask));
y0 = mean(y(referenceMask));
scaleX = max((cols-1)/2,1);
scaleY = max((rows-1)/2,1);
xn = (x(referenceMask)-x0)/scaleX;
yn = (y(referenceMask)-y0)/scaleY;
design = [xn, yn, ones(numel(xn),1)];
observed = unwrappedPhase(referenceMask);
baseWeights = max(qualityMap(referenceMask), eps).^2;
weights = baseWeights;

for iteration = 1:4
    sw = sqrt(weights);
    weightedDesign = design .* sw;
    if rank(weightedDesign) < 3
        error('Tilt reference has insufficient 2-D coverage to define a plane.');
    end
    beta = weightedDesign \ (observed .* sw);
    residual = observed - design*beta;
    sigma = 1.4826*median(abs(residual - median(residual)));
    if sigma < 1e-9
        break
    end
    huber = min(1, (1.5*sigma) ./ max(abs(residual),eps));
    weights = baseWeights .* huber;
end

plane = beta(1)*(x-x0)/scaleX + ...
    beta(2)*(y-y0)/scaleY + beta(3);
correctedPhase = unwrappedPhase - plane;
correctedPhase(~validMask) = NaN;

coefficients.xRadPerPixel = beta(1)/scaleX;
coefficients.yRadPerPixel = beta(2)/scaleY;
coefficients.offsetRad = beta(3) - ...
    coefficients.xRadPerPixel*x0 - coefficients.yRadPerPixel*y0;
coefficients.referencePixelCount = nnz(referenceMask);
coefficients.referenceRmsRad = sqrt(mean((observed - design*beta).^2));
coefficients.roi = roi;
end
