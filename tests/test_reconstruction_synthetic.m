function test_reconstruction_synthetic
%TEST_RECONSTRUCTION_SYNTHETIC Check 2-D unwrap, spikes, and reference tilt.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));

rng(1);
[x, y] = meshgrid(1:100, 1:80);
truePhase = 0.055*x + 0.035*y + ...
    1.4*exp(-((x-55).^2 + (y-47).^2)/180);
wrapped = angle(exp(1i*(truePhase + 0.02*randn(size(x)))));

quality = 0.9*ones(size(x));
quality(20:25,30:40) = 0;
[unwrapped, valid, info] = psi.processing.unwrapPhaseQuality( ...
    wrapped, quality, 0.1);

assert(nnz(valid) == numel(quality) - 6*11);
assert(info.componentCount == 1);
residual = unwrapped(valid) - truePhase(valid);
residual = residual - median(residual);
assert(sqrt(mean(residual.^2)) < 0.08);

unwrapped(60,75) = unwrapped(60,75) + 2*pi;
[clean, spikeMask] = psi.processing.rejectPhaseSpikes(unwrapped, pi);
assert(spikeMask(60,75) && isnan(clean(60,75)));

roi = [3 3 18 14];
[corrected, ~, coefficients, kept, reference] = ...
    psi.processing.removeTiltPlane(clean, quality, 0.1, roi);
assert(nnz(reference) >= 25);
assert(nnz(reference) < nnz(kept));
assert(abs(coefficients.xRadPerPixel - 0.055) < 0.01);
assert(abs(coefficients.yRadPerPixel - 0.035) < 0.01);
assert(isnan(corrected(60,75)));
assert(isnan(corrected(22,35)));
end
