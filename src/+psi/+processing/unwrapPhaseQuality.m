function [unwrappedPhase, validMask, diagnostics] = unwrapPhaseQuality(wrappedPhase, qualityMap, threshold)
%UNWRAPPHASEQUALITY Quality-guided 2-D unwrapping on a reliable pixel graph.
% A maximum-reliability spanning forest prevents propagation through invalid
% pixels. Only the largest connected component has a defined phase origin.

[rows, cols] = size(wrappedPhase);
n = numel(wrappedPhase);
valid = isfinite(wrappedPhase) & isfinite(qualityMap) & ...
    qualityMap >= threshold;

unwrappedPhase = nan(rows, cols);
validMask = false(rows, cols);
diagnostics.reliablePixels = nnz(valid);
diagnostics.connectedPixels = 0;
diagnostics.componentCount = 0;

if ~any(valid)
    error('No reliable pixels for 2-D phase unwrapping.');
end

indices = reshape(int32(1:n), rows, cols);
from = [reshape(indices(:,1:end-1), [], 1); ...
        reshape(indices(1:end-1,:), [], 1)];
to = [reshape(indices(:,2:end), [], 1); ...
      reshape(indices(2:end,:), [], 1)];

keep = valid(from) & valid(to);
from = from(keep);
to = to(keep);

raw = wrappedPhase(to) - wrappedPhase(from);
step = mod(raw + pi, 2*pi) - pi;
turnStep = int32(round((step - raw) / (2*pi)));
q = min(qualityMap(from), qualityMap(to));
reliability = q.^2 .* (1 - 0.4 * abs(step)/pi);
[~, order] = sort(reliability, 'descend');

parent = int32(1:n)';
componentSize = ones(n, 1, 'int32');
turnToParent = zeros(n, 1, 'int32');

for j = 1:numel(order)
    k = order(j);
    a = from(k);
    b = to(k);

    [rootA, turnA] = findRoot(a);
    [rootB, turnB] = findRoot(b);
    if rootA == rootB
        continue
    end

    % The integer phase turn at b minus that at a equals turnStep(k).
    if componentSize(rootA) >= componentSize(rootB)
        parent(rootB) = rootA;
        turnToParent(rootB) = turnStep(k) + turnA - turnB;
        componentSize(rootA) = componentSize(rootA) + componentSize(rootB);
    else
        parent(rootA) = rootB;
        turnToParent(rootA) = turnB - turnA - turnStep(k);
        componentSize(rootB) = componentSize(rootB) + componentSize(rootA);
    end
end

roots = find(valid & parent == indices(:));
diagnostics.componentCount = numel(roots);
[~, largest] = max(componentSize(roots));
mainRoot = roots(largest);

unwrapped = nan(n,1);
for j = find(valid(:))'
    [root, turns] = findRoot(int32(j));
    if root == mainRoot
        unwrapped(j) = wrappedPhase(j) + 2*pi*double(turns);
    end
end

unwrappedPhase(:) = unwrapped;
validMask = isfinite(unwrappedPhase);
diagnostics.connectedPixels = nnz(validMask);

    function [root, turns] = findRoot(index)
        root = index;
        turns = int32(0);
        while parent(root) ~= root
            turns = turns + turnToParent(root);
            root = parent(root);
        end
    end
end
