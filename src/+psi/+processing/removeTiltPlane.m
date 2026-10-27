function [correctedPhase, plane, coefficients, validMask, referenceMask] = ...
    removeTiltPlane(unwrappedPhase, qualityMap, threshold, roi)
%REMOVETILTPLANE Robust 2-D tilt fit using compact weighted 3-by-3 systems.

if nargin < 4
    roi = [];
end
[rows, cols] = size(unwrappedPhase);
validMask = isfinite(unwrappedPhase) & isfinite(qualityMap) & ...
    qualityMap > 0 & qualityMap >= threshold;
referenceMask = validMask;

if ~isempty(roi)
    if numel(roi) ~= 4 || any(~isfinite(roi)) || any(roi(3:4) <= 0)
        error('Tilt reference ROI must be [x y width height] with positive size.');
    end
    x1 = max(1, ceil(roi(1)));
    x2 = min(cols, floor(roi(1)+roi(3)));
    y1 = max(1, ceil(roi(2)));
    y2 = min(rows, floor(roi(2)+roi(4)));
    referenceMask(:) = false;
    if x1 <= x2 && y1 <= y2
        referenceMask(y1:y2, x1:x2) = validMask(y1:y2, x1:x2);
    end
end

if nnz(referenceMask) < 25
    error('Tilt reference has fewer than 25 reliable pixels. Choose a larger flat ROI.');
end

[refRow, refCol] = find(referenceMask);
scaleX = max((cols-1)/2,1);
scaleY = max((rows-1)/2,1);
x0 = mean(refCol);
y0 = mean(refRow);
xn = (double(refCol)-x0)/scaleX;
yn = (double(refRow)-y0)/scaleY;
observed = unwrappedPhase(referenceMask);
baseWeights = qualityMap(referenceMask).^2;
weights = baseWeights;

for iteration = 1:4
    xx = sum(weights .* xn.^2);
    xy = sum(weights .* xn .* yn);
    yy = sum(weights .* yn.^2);
    xw = sum(weights .* xn);
    yw = sum(weights .* yn);
    sw = sum(weights);

    gram = [xx, xy, xw; xy, yy, yw; xw, yw, sw];
    if rcond(gram) < 1e-12
        error('Tilt reference has insufficient 2-D coverage to define a plane.');
    end
    rhs = [sum(weights .* xn .* observed); ...
           sum(weights .* yn .* observed); ...
           sum(weights .* observed)];
    beta = gram \ rhs;
    residual = observed - (beta(1)*xn + beta(2)*yn + beta(3));
    sigma = 1.4826 * median(abs(residual - median(residual)));
    if sigma < 1e-9
        break
    end
    weights = baseWeights .* min(1, 1.5*sigma ./ max(abs(residual),eps));
end

ax = beta(1)/scaleX;
ay = beta(2)/scaleY;
intercept = beta(3) - ax*x0 - ay*y0;
plane = ax*(1:cols) + ay*(1:rows)' + intercept;
correctedPhase = unwrappedPhase - plane;
correctedPhase(~validMask) = NaN;

coefficients.xRadPerPixel = ax;
coefficients.yRadPerPixel = ay;
coefficients.offsetRad = intercept;
coefficients.referencePixelCount = nnz(referenceMask);
coefficients.referenceRmsRad = sqrt(mean(residual.^2));
coefficients.roi = roi;
end
