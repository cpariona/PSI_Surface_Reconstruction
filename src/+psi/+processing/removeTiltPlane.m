function [correctedPhase, plane, coefficients, validMask] = ...
    removeTiltPlane(unwrappedPhase, qualityMap, threshold)
%REMOVETILTPLANE Remove the best-fit 2-D phase plane using reliable pixels.

[rows, cols] = size(unwrappedPhase);
[x, y] = meshgrid(1:cols, 1:rows);

x0 = (cols + 1) / 2;
y0 = (rows + 1) / 2;
xs = max((cols - 1) / 2, 1);
ys = max((rows - 1) / 2, 1);

xn = (x - x0) / xs;
yn = (y - y0) / ys;

validMask = qualityMap >= threshold & isfinite(unwrappedPhase);
if nnz(validMask) < 3
    validMask = isfinite(unwrappedPhase);
end

w = qualityMap(validMask).^2;
w(w == 0) = 1;

xv = xn(validMask);
yv = yn(validMask);
zv = unwrappedPhase(validMask);

A = [sum(w .* xv .* xv), sum(w .* xv .* yv), sum(w .* xv); ...
     sum(w .* xv .* yv), sum(w .* yv .* yv), sum(w .* yv); ...
     sum(w .* xv),       sum(w .* yv),       sum(w)];
b = [sum(w .* xv .* zv); ...
     sum(w .* yv .* zv); ...
     sum(w .* zv)];

beta = A \ b;
plane = beta(1) * xn + beta(2) * yn + beta(3);
correctedPhase = unwrappedPhase - plane;

coefficients.xRadPerPixel = beta(1) / xs;
coefficients.yRadPerPixel = beta(2) / ys;
coefficients.offsetRad = beta(3);
end
