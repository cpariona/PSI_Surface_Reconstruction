function scan = acquireFringeScan(piezo, camera, acquisition, outputDir, frameCallback)
%ACQUIREFRINGESCAN Sweep piezo voltage and save one interferogram per step.

if nargin < 5
    frameCallback = [];
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

commandedVoltage = acquisition.startVoltage + ...
    (0:acquisition.imageCount-1) * acquisition.stepVoltage;
measuredVoltage = zeros(size(commandedVoltage));
imageFiles = strings(size(commandedVoltage));
startedAt = datetime('now');

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

save(fullfile(outputDir, 'metadata.mat'), 'scan');
end

function setZero(piezo)
try
    piezo.setVoltage(0);
catch
end
end
