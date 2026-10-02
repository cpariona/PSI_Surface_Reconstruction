function unwrappedPhase = unwrapPhase(wrappedPhase)
%UNWRAPPHASE Unwrap phase first across rows and then across columns.

unwrappedPhase = unwrap(wrappedPhase, [], 2);
unwrappedPhase = unwrap(unwrappedPhase, [], 1);
end
