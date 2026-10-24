function scan = acquireFringeScan(piezo, camera, acquisition, outputDir, frameCallback)
%ACQUIREFRINGESCAN Sweep piezo voltage and save one interferogram per step.

if nargin < 5
    frameCallback = [];
end

commandedVoltage = acquisition.startVoltage + ...
    (0:acquisition.imageCount-1) * acquisition.stepVoltage;

if isempty(commandedVoltage) || acquisition.imageCount < 1
    error('Image count must be at least 1.');
end

requestedMin = min(commandedVoltage);
requestedMax = max(commandedVoltage);
if requestedMin < 0 || requestedMax > piezo.SafeMaxVoltage
    error(['Requested voltage range is %.3f to %.3f V. ' ...
        'Safe piezo range is 0 to %.3f V. Acquisition was not started.'], ...
        requestedMin, requestedMax, piezo.SafeMaxVoltage);
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

measuredVoltage = zeros(size(commandedVoltage));
imageFiles = strings(size(commandedVoltage));
startedAt = datetime('now');

cameraSettings.exposureMs = camera.getExposure();
cameraSettings.gainPercent = camera.getGain();

cleanup = onCleanup(@() setZero(piezo)); %#ok<NASGU>

for k = 1:numel(commandedVoltage)
    piezo.setVoltage(commandedVoltage(k));
    pause(acquisition.settleTime);

    frame = camera.capture();
    measuredVoltage(k) = piezo.readVoltage();

    fileName = sprintf('image%d.bmp', k-1);
    imwrite(frame, fullfile(outputDir, fileName));
    imageFiles(k) = string(fileName);

    if ~isempty(frameCallback)
        frameCallback(frame, k, numel(commandedVoltage), ...
            commandedVoltage(k), measuredVoltage(k));
    end
end

scan.outputDir = string(outputDir);
scan.imageFiles = imageFiles;
scan.commandedVoltage = commandedVoltage;
scan.measuredVoltage = measuredVoltage;
scan.startedAt = startedAt;
scan.completedAt = datetime('now');
scan.acquisition = acquisition;
scan.camera = cameraSettings;
scan.piezoMaxVoltage = piezo.MaxVoltage;
scan.piezoSafeMaxVoltage = piezo.SafeMaxVoltage;

save(fullfile(outputDir, 'metadata.mat'), 'scan');
end

function setZero(piezo)
try
    piezo.setVoltage(0);
catch
end
end
