function [cleanPhase, spikeMask] = rejectPhaseSpikes(unwrappedPhase, thresholdRad)
%REJECTPHASESPIKES Mask isolated phase outliers; never invent missing heights.

[rows, cols] = size(unwrappedPhase);
neighbors = nan(rows, cols, 4);
neighbors(2:end,:,1) = unwrappedPhase(1:end-1,:);
neighbors(1:end-1,:,2) = unwrappedPhase(2:end,:);
neighbors(:,2:end,3) = unwrappedPhase(:,1:end-1);
neighbors(:,1:end-1,4) = unwrappedPhase(:,2:end);

neighborCount = sum(isfinite(neighbors), 3);
localMedian = median(neighbors, 3, 'omitnan');
localSpread = median(abs(neighbors - localMedian), 3, 'omitnan');

spikeMask = isfinite(unwrappedPhase) & neighborCount >= 3 & ...
    abs(unwrappedPhase - localMedian) > thresholdRad & ...
    localSpread < thresholdRad/3;

cleanPhase = unwrappedPhase;
cleanPhase(spikeMask) = NaN;
end
