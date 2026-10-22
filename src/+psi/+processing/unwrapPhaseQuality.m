function unwrappedPhase = unwrapPhaseQuality(wrappedPhase, qualityMap, threshold)
%UNWRAPPHASEQUALITY Unwrap rows and align them using reliable vertical phase differences.

unwrappedPhase = unwrap(wrappedPhase, [], 2);

for row = 2:size(wrappedPhase,1)
    valid = qualityMap(row,:) >= threshold & ...
        qualityMap(row-1,:) >= threshold;

    if ~any(valid)
        valid = true(1, size(wrappedPhase,2));
    end

    wrappedStep = angle(exp(1i * ...
        (wrappedPhase(row,valid) - wrappedPhase(row-1,valid))));
    currentStep = unwrappedPhase(row,valid) - ...
        unwrappedPhase(row-1,valid);

    turns = round(median((currentStep - wrappedStep) / (2*pi)));
    unwrappedPhase(row,:) = unwrappedPhase(row,:) - 2*pi*turns;
end
end
