function [unwrappedPhase, validMask, diagnostics] = unwrapPhaseQuality(wrappedPhase, qualityMap, threshold)
%UNWRAPPHASEQUALITY Quality-guided 2-D unwrap using native graph algorithms.
% Native minspantree replaces millions of interpreted union-find operations.
% Disconnected low-quality regions remain NaN; no phase is interpolated.

[rows, cols] = size(wrappedPhase);
valid = isfinite(wrappedPhase) & isfinite(qualityMap) & ...
    qualityMap > 0 & qualityMap >= threshold;
validIndices = find(valid(:));
numValid = numel(validIndices);

if numValid == 0
    error('No reliable pixels for 2-D phase unwrapping.');
end

% Compact node numbering avoids graph nodes for excluded pixels.
indexMap = zeros(rows*cols, 1, 'uint32');
indexMap(validIndices) = uint32(1:numValid);
pixels = reshape(uint32(1:rows*cols), rows, cols);

src = [reshape(pixels(:,1:end-1), [], 1); ...
       reshape(pixels(1:end-1,:), [], 1)];
dst = [reshape(pixels(:,2:end), [], 1); ...
       reshape(pixels(2:end,:), [], 1)];
keep = valid(src) & valid(dst);
src = src(keep);
dst = dst(keep);

rawStep = wrappedPhase(dst) - wrappedPhase(src);
wrappedStep = mod(rawStep + pi, 2*pi) - pi;
quality = min(qualityMap(src), qualityMap(dst));
reliability = quality.^2 .* (1 - 0.4*abs(wrappedStep)/pi);

G = graph(double(indexMap(src)), double(indexMap(dst)), ...
    -reliability, numValid);
componentId = conncomp(G);
componentSizes = accumarray(componentId(:), 1);
[~, largestComponent] = max(componentSizes);
root = find(componentId == largestComponent, 1, 'first');

% Sparse Kruskal is compiled; negated edge weights preserve maximum reliability.
[T, predecessor] = minspantree(G, 'Method', 'sparse', ...
    'Type', 'tree', 'Root', root);
order = dfsearch(T, root);
count = numel(order);

% Propagate integer 2*pi turns along the directed spanning tree.
child = order(2:end);
parent = predecessor(child);
wrappedVector = wrappedPhase(validIndices);
delta = wrappedVector(child) - wrappedVector(parent);
principalDelta = mod(delta + pi, 2*pi) - pi;
edgeTurns = int32(round((principalDelta - delta) / (2*pi)));
turns = zeros(numValid, 1, 'int32');
for k = 1:numel(child)
    turns(child(k)) = turns(parent(k)) + edgeTurns(k);
end

unwrappedPhase = nan(rows, cols);
unwrappedPhase(validIndices(order)) = ...
    wrappedVector(order) + 2*pi*double(turns(order));
validMask = isfinite(unwrappedPhase);

diagnostics.reliablePixels = numValid;
diagnostics.connectedPixels = count;
diagnostics.componentCount = numel(componentSizes);
end
