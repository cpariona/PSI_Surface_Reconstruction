function cfg = system_config
%SYSTEM_CONFIG Hardware, acquisition, and PSI defaults.

cfg.hardware.kinesisPath = 'C:\Program Files\Thorlabs\Kinesis';
cfg.hardware.cameraDll = ['C:\Program Files\Thorlabs\Scientific Imaging\' ...
    'DCx Camera Support\Develop\DotNet\uc480DotNet.dll'];
cfg.hardware.piezoSerial = '81857565';
cfg.hardware.actuatorMaxVoltage = []; % Set only when the actuator limit is known.

cfg.acquisition.startVoltage = 0;
cfg.acquisition.stepVoltage = 0.1;
cfg.acquisition.imageCount = 85;
cfg.acquisition.settleTime = 0.5;

cfg.processing.phaseStepDeg = 90;
cfg.processing.phaseToleranceDeg = 5;
cfg.processing.wavelengthNm = 660;
cfg.processing.analysisRow = [];
cfg.processing.referenceRow = [];

cfg.processing.filterRadius = 2;
cfg.processing.qualityThreshold = 0.10;
cfg.processing.spikeThresholdRad = pi;
cfg.processing.tiltROI = []; % [] = full field; prefer a flat reference ROI.
cfg.processing.computeV2Comparison = false; % Opt-in: costly four-frame comparison.
cfg.processing.previewMaxPixels = 350; % Max image dimension for 3-D preview.
end
