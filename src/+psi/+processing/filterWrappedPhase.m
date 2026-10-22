function filteredPhase = filterWrappedPhase(wrappedPhase, qualityMap, radius)
%FILTERWRAPPEDPHASE Quality-weighted circular smoothing of wrapped phase.

kernel = ones(2*radius + 1);
weights = qualityMap.^2;
phasor = exp(1i * wrappedPhase);

numerator = conv2(weights .* phasor, kernel, 'same');
denominator = conv2(weights, kernel, 'same');

filteredPhase = angle(numerator ./ max(denominator, eps));
filteredPhase(denominator <= eps) = wrappedPhase(denominator <= eps);
end
