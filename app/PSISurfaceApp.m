function PSISurfaceApp
%PSISURFACEAPP GUI for PSI acquisition and surface reconstruction.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'), fullfile(root, 'config'));
cfg = system_config();

piezo = [];
camera = [];
defaultFolder = fullfile(root, 'data', datestr(now, 'yyyymmdd_HHMMSS'));

fig = uifigure('Name', 'PSI Surface Reconstruction', ...
    'Position', [100 100 1200 760]);
fig.CloseRequestFcn = @closeApp;

main = uigridlayout(fig, [1 2]);
main.ColumnWidth = {300, '1x'};
main.Padding = [10 10 10 10];

panel = uipanel(main, 'Title', 'Acquisition');
panel.Layout.Row = 1;
panel.Layout.Column = 1;
controls = uigridlayout(panel, [14 2]);
controls.ColumnWidth = {'1x', 110};
controls.RowHeight = {32, 28, 28, 28, 28, 28, 28, 24, 48, 32, 32, 32, 32, '1x'};

connectButton = uibutton(controls, 'Text', 'Connect', ...
    'ButtonPushedFcn', @connectHardware);
connectButton.Layout.Row = 1;
connectButton.Layout.Column = 1;

disconnectButton = uibutton(controls, 'Text', 'Disconnect', ...
    'Enable', 'off', 'ButtonPushedFcn', @disconnectHardware);
disconnectButton.Layout.Row = 1;
disconnectButton.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Start voltage (V)');
label.Layout.Row = 2; label.Layout.Column = 1;
startVoltage = uieditfield(controls, 'numeric', 'Value', cfg.acquisition.startVoltage);
startVoltage.Layout.Row = 2; startVoltage.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Step voltage (V)');
label.Layout.Row = 3; label.Layout.Column = 1;
stepVoltage = uieditfield(controls, 'numeric', 'Value', cfg.acquisition.stepVoltage);
stepVoltage.Layout.Row = 3; stepVoltage.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Images');
label.Layout.Row = 4; label.Layout.Column = 1;
imageCount = uieditfield(controls, 'numeric', 'Value', cfg.acquisition.imageCount);
imageCount.Layout.Row = 4; imageCount.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Settling time (s)');
label.Layout.Row = 5; label.Layout.Column = 1;
settleTime = uieditfield(controls, 'numeric', 'Value', cfg.acquisition.settleTime);
settleTime.Layout.Row = 5; settleTime.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Phase tolerance (deg)');
label.Layout.Row = 6; label.Layout.Column = 1;
phaseTolerance = uieditfield(controls, 'numeric', 'Value', cfg.processing.phaseToleranceDeg);
phaseTolerance.Layout.Row = 6; phaseTolerance.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Wavelength (nm)');
label.Layout.Row = 7; label.Layout.Column = 1;
wavelength = uieditfield(controls, 'numeric', 'Value', cfg.processing.wavelengthNm);
wavelength.Layout.Row = 7; wavelength.Layout.Column = 2;

folderLabel = uilabel(controls, 'Text', 'Acquisition folder');
folderLabel.Layout.Row = 8;
folderLabel.Layout.Column = [1 2];

folderField = uieditfield(controls, 'text', 'Value', defaultFolder);
folderField.Layout.Row = 9;
folderField.Layout.Column = [1 2];

browseButton = uibutton(controls, 'Text', 'Select folder', ...
    'ButtonPushedFcn', @browseFolder);
browseButton.Layout.Row = 10;
browseButton.Layout.Column = [1 2];

acquireButton = uibutton(controls, 'Text', 'Acquire fringe scan', ...
    'Enable', 'off', 'ButtonPushedFcn', @acquireScan);
acquireButton.Layout.Row = 11;
acquireButton.Layout.Column = [1 2];

reconstructButton = uibutton(controls, 'Text', 'Reconstruct surface', ...
    'ButtonPushedFcn', @reconstructScan);
reconstructButton.Layout.Row = 12;
reconstructButton.Layout.Column = [1 2];

statusLabel = uilabel(controls, 'Text', 'Disconnected', ...
    'HorizontalAlignment', 'center');
statusLabel.Layout.Row = 13;
statusLabel.Layout.Column = [1 2];

views = uitabgroup(main);
views.Layout.Row = 1;
views.Layout.Column = 2;

imageTab = uitab(views, 'Title', 'Interferogram');
imageGrid = uigridlayout(imageTab, [1 1]);
imageAxes = uiaxes(imageGrid);
title(imageAxes, 'Camera image');
axis(imageAxes, 'image');
colormap(imageAxes, 'gray');

phaseTab = uitab(views, 'Title', 'Wrapped phase');
phaseGrid = uigridlayout(phaseTab, [1 1]);
phaseAxes = uiaxes(phaseGrid);
title(phaseAxes, 'Wrapped phase');
axis(phaseAxes, 'image');
colormap(phaseAxes, 'gray');

surfaceTab = uitab(views, 'Title', 'Surface');
surfaceGrid = uigridlayout(surfaceTab, [1 1]);
surfaceAxes = uiaxes(surfaceGrid);
title(surfaceAxes, 'Surface (nm)');

    function connectHardware(~,~)
        try
            statusLabel.Text = 'Connecting...';
            drawnow;
            piezo = psi.hardware.TPZ001Controller(cfg.hardware);
            camera = psi.hardware.DCC1545MCamera(cfg.hardware);

            frame = camera.capture();
            imagesc(imageAxes, frame);
            axis(imageAxes, 'image');
            colormap(imageAxes, 'gray');

            connectButton.Enable = 'off';
            disconnectButton.Enable = 'on';
            acquireButton.Enable = 'on';
            statusLabel.Text = 'Connected';
        catch ME
            disconnectHardware();
            statusLabel.Text = 'Connection failed';
            uialert(fig, ME.message, 'Hardware connection');
        end
    end

    function disconnectHardware(varargin)
        if ~isempty(camera)
            delete(camera);
            camera = [];
        end
        if ~isempty(piezo)
            delete(piezo);
            piezo = [];
        end
        connectButton.Enable = 'on';
        disconnectButton.Enable = 'off';
        acquireButton.Enable = 'off';
        statusLabel.Text = 'Disconnected';
    end

    function browseFolder(~,~)
        startFolder = fileparts(folderField.Value);
        if ~isfolder(startFolder)
            startFolder = root;
        end
        selected = uigetdir(startFolder, 'Select acquisition folder');
        if ~isequal(selected, 0)
            folderField.Value = selected;
        end
    end

    function acquireScan(~,~)
        acquisition = cfg.acquisition;
        acquisition.startVoltage = startVoltage.Value;
        acquisition.stepVoltage = stepVoltage.Value;
        acquisition.imageCount = round(imageCount.Value);
        acquisition.settleTime = settleTime.Value;

        acquireButton.Enable = 'off';
        statusLabel.Text = 'Acquiring...';
        drawnow;

        try
            psi.acquisition.acquireFringeScan(piezo, camera, acquisition, ...
                folderField.Value, @updatePreview);
            statusLabel.Text = 'Acquisition complete';
        catch ME
            statusLabel.Text = 'Acquisition failed';
            uialert(fig, ME.message, 'Acquisition');
        end
        acquireButton.Enable = 'on';
    end

    function updatePreview(frame, index, count, commanded, measured)
        imagesc(imageAxes, frame);
        axis(imageAxes, 'image');
        statusLabel.Text = sprintf('%d/%d | %.3f V -> %.3f V', ...
            index, count, commanded, measured);
        drawnow limitrate;
    end

    function reconstructScan(~,~)
        processing = cfg.processing;
        processing.phaseToleranceDeg = phaseTolerance.Value;
        processing.wavelengthNm = wavelength.Value;

        statusLabel.Text = 'Reconstructing...';
        drawnow;

        try
            result = psi.processing.reconstructSurface( ...
                folderField.Value, processing);

            imagesc(phaseAxes, result.wrappedPhase);
            axis(phaseAxes, 'image');
            colormap(phaseAxes, 'gray');

            surf(surfaceAxes, result.surfaceNm, 'EdgeColor', 'none');
            axis(surfaceAxes, 'tight');
            view(surfaceAxes, 3);
            xlabel(surfaceAxes, 'x (pixel)');
            ylabel(surfaceAxes, 'y (pixel)');
            zlabel(surfaceAxes, 'height (nm)');
            colorbar(surfaceAxes);

            statusLabel.Text = sprintf('Reconstruction complete | frames %s', ...
                mat2str(result.selectedImageNumbers));
        catch ME
            statusLabel.Text = 'Reconstruction failed';
            uialert(fig, ME.message, 'Reconstruction');
        end
    end

    function closeApp(~,~)
        disconnectHardware();
        delete(fig);
    end
end
