function [polarity, direction, motion] = inferHeightPolarity(phaseSteps, override)
%INFERHEIGHTPOLARITY Calibrate height sign from the temporal fringe drift.
% For a positive spatial FFT carrier, increasing phase shifts the fringes
% to the left; decreasing phase shifts them to the right.
% Laboratory convention: left => +1, right => -1 in surface height.
%
% An explicitly supplied polarity (+1/-1) overrides automatic detection.
% Motion direction alone is not a universal physical height calibration.

if nargin < 2
    override = [];
end
if ~isempty(override)
    if ~isnumeric(override) || ~isscalar(override) || ...
            ~isfinite(override) || ~ismember(override, [-1, 1])
        error('Height polarity override must be empty, +1, or -1.');
    end
end

steps = double(phaseSteps(:));
if numel(steps) < 3 || any(~isfinite(steps))
    error('At least three finite phase steps are needed for direction detection.');
end

increments = diff(steps);
drift = median(increments);
signAgreement = mean(sign(increments) == sign(drift));
motion.meanStepDeg = mean(increments) * 180/pi;
motion.medianStepDeg = drift * 180/pi;
motion.signAgreement = signAgreement;

if abs(drift) >= 0.005 && signAgreement >= 0.7
    if drift > 0
        direction = "left";
        inferredPolarity = 1;
    else
        direction = "right";
        inferredPolarity = -1;
    end
else
    direction = "ambiguous";
    inferredPolarity = NaN;
end

if isempty(override)
    if isnan(inferredPolarity)
        error(['Fringe motion direction is ambiguous (median step %.3f deg, ' ...
            'consistency %.0f%%). Set processing.heightPolarity to +1 or -1 ' ...
            'in system_config.m to use the calibrated sign.'], ...
            motion.medianStepDeg, 100*motion.signAgreement);
    end
    polarity = inferredPolarity;
    motion.source = "automatic";
else
    polarity = double(override);
    motion.source = "manual";
end
end
