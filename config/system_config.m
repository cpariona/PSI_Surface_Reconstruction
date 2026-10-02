function cfg = system_config
%SYSTEM_CONFIG Hardware, acquisition, and PSI defaults.

cfg.hardware.kinesisPath = 'C:\Program Files\Thorlabs\Kinesis';
cfg.hardware.cameraDll = ['C:\Program Files\Thorlabs\Scientific Imaging\' ...
    'DCx Camera Support\Develop\DotNet\uc480DotNet.dll'];
cfg.hardware.piezoSerial = '81857565';

cfg.acquisition.startVoltage = 0;
cfg.acquisition.stepVoltage = 0.1;
cfg.acquisition.imageCount = 85;
cfg.acquisition.settleTime = 0.5;

cfg.processing.phaseStepDeg = 90;
cfg.processing.phaseToleranceDeg = 5;
cfg.processing.wavelengthNm = 660;
cfg.processing.analysisRow = [];
cfg.processing.referenceRow = [];
end
