function result = run_surface_reconstruction(folder)
%RUN_SURFACE_RECONSTRUCTION Minimal command-line reconstruction workflow.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'), fullfile(root, 'config'));

cfg = system_config();
result = psi.processing.reconstructSurface(folder, cfg.processing);
end
