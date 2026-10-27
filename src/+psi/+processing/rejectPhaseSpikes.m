function [cleanPhase, spikeMask] = rejectPhaseSpikes(unwrappedPhase, thresholdRad)
%REJECTPHASESPIKES Detect isolated outliers using four neighbor 2-D arrays.
% A fixed sorting network avoids 3-D neighbor arrays and omitnan medians.

[rows, cols] = size(unwrappedPhase);
north = inf(rows, cols);
south = north;
west = north;
east = north;
north(2:end,:) = unwrappedPhase(1:end-1,:);
south(1:end-1,:) = unwrappedPhase(2:end,:);
west(:,2:end) = unwrappedPhase(:,1:end-1);
east(:,1:end-1) = unwrappedPhase(:,2:end);

north(~isfinite(north)) = Inf;
south(~isfinite(south)) = Inf;
west(~isfinite(west)) = Inf;
east(~isfinite(east)) = Inf;

count = isfinite(north) + isfinite(south) + ...
    isfinite(west) + isfinite(east);

[a,b,c,d] = sortFour(north, south, west, east);
localMedian = b;
allFour = count == 4;
localMedian(allFour) = (b(allFour) + c(allFour))/2;

[a,b,c,d] = sortFour(abs(a-localMedian), abs(b-localMedian), ...
    abs(c-localMedian), abs(d-localMedian));
localSpread = b;
localSpread(allFour) = (b(allFour) + c(allFour))/2;

spikeMask = isfinite(unwrappedPhase) & count >= 3 & ...
    abs(unwrappedPhase - localMedian) > thresholdRad & ...
    localSpread < thresholdRad/3;

cleanPhase = unwrappedPhase;
cleanPhase(spikeMask) = NaN;
end

function [a,b,c,d] = sortFour(a,b,c,d)
% Compare/swap sorting network, ascending.
t = min(a,b); b = max(a,b); a = t;
t = min(c,d); d = max(c,d); c = t;
t = min(a,c); c = max(a,c); a = t;
t = min(b,d); d = max(b,d); b = t;
t = min(b,c); c = max(b,c); b = t;
end
