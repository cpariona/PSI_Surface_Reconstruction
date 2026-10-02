function correctedPhase = removeCarrier(unwrappedPhase, fringeFrequency, referenceRow)
%REMOVECARRIER Remove the linear fringe carrier and reference offset.

[rows, cols] = size(unwrappedPhase);
if nargin < 3 || isempty(referenceRow)
    referenceRow = round(rows/2);
end

x = 1:cols;
carrier = repmat(2*pi*fringeFrequency*x/cols, rows, 1);
correctedPhase = carrier - unwrappedPhase;
correctedPhase = correctedPhase - mean(correctedPhase(referenceRow,:));
end
