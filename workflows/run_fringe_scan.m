function scan = run_fringe_scan(outputDir)
%RUN_FRINGE_SCAN Minimal command-line acquisition workflow.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'), fullfile(root, 'config'));

cfg = system_config();
if nargin < 1 || isempty(outputDir)
    outputDir = fullfile(root, 'data', datestr(now, 'yyyymmdd_HHMMSS'));
end

piezo = psi.hardware.TPZ001Controller(cfg.hardware);
camera = psi.hardware.DCC1545MCamera(cfg.hardware);
cleanup = onCleanup(@() closeHardware(camera, piezo)); %#ok<NASGU>

scan = psi.acquisition.acquireFringeScan( ...
    piezo, camera, cfg.acquisition, outputDir);
end

function closeHardware(camera, piezo)
delete(camera);
delete(piezo);
end
