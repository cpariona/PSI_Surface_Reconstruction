function PSISurfaceApp
%PSISURFACEAPP GUI for PSI acquisition and surface reconstruction.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'), fullfile(root, 'config'));
cfg = system_config();

piezo = [];
camera = [];
previewTimer = [];
imageHandle = [];
histHandle = [];
crosshairX = [];
crosshairY = [];
crosshairPos = [];
crosshairDragging = false;
horizontalProfileHandle = [];
verticalProfileHandle = [];
isAcquiring = false;
cameraFault = false;
defaultFolder = fullfile(root, 'data', datestr(now, 'yyyymmdd_HHMMSS'));

fig = uifigure('Name', 'PSI Surface Reconstruction', ...
    'Position', [100 100 1200 760]);
fig.CloseRequestFcn = @closeApp;

main = uigridlayout(fig, [1 2]);
main.ColumnWidth = {320, '1x'};
main.Padding = [10 10 10 10];

panel = uipanel(main, 'Title', 'Acquisition');
panel.Layout.Row = 1;
panel.Layout.Column = 1;
controls = uigridlayout(panel, [20 2]);
controls.ColumnWidth = {'1x', 120};
controls.RowHeight = {32, 32, 28, 28, 32, 28, 28, 28, 28, 28, 28, 24, ...
    48, 32, 32, 32, 32, 32, 32, '1x'};

connectButton = uibutton(controls, 'Text', 'Connect', ...
    'ButtonPushedFcn', @connectHardware);
connectButton.Layout.Row = 1;
connectButton.Layout.Column = 1;

disconnectButton = uibutton(controls, 'Text', 'Disconnect', ...
    'Enable', 'off', 'ButtonPushedFcn', @disconnectHardware);
disconnectButton.Layout.Row = 1;
disconnectButton.Layout.Column = 2;

cameraButton = uibutton(controls, 'Text', 'Camera On', ...
    'Enable', 'off', 'ButtonPushedFcn', @toggleCameraPreview);
cameraButton.Layout.Row = 2;
cameraButton.Layout.Column = [1 2];

label = uilabel(controls, 'Text', 'Exposure (ms)');
label.Layout.Row = 3; label.Layout.Column = 1;
exposureField = uieditfield(controls, 'numeric', 'Enable', 'off');
exposureField.Layout.Row = 3; exposureField.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Gain (%)');
label.Layout.Row = 4; label.Layout.Column = 1;
gainField = uieditfield(controls, 'numeric', 'Limits', [0 100], ...
    'Enable', 'off');
gainField.Layout.Row = 4; gainField.Layout.Column = 2;

applyCameraButton = uibutton(controls, 'Text', 'Apply camera settings', ...
    'Enable', 'off', 'ButtonPushedFcn', @applyCameraSettings);
applyCameraButton.Layout.Row = 5;
applyCameraButton.Layout.Column = [1 2];

crosshairCheck = uicheckbox(controls, 'Text', 'Show crosshair', ...
    'Value', true, 'ValueChangedFcn', @updateCrosshair);
crosshairCheck.Layout.Row = 6;
crosshairCheck.Layout.Column = 1;

crosshairLabel = uilabel(controls, 'Text', 'x: -   y: -', ...
    'HorizontalAlignment', 'right');
crosshairLabel.Layout.Row = 6;
crosshairLabel.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Start voltage (V)');
label.Layout.Row = 7; label.Layout.Column = 1;
startVoltage = uieditfield(controls, 'numeric', ...
    'Value', cfg.acquisition.startVoltage, ...
    'ValueChangedFcn', @updateVoltageStatus);
startVoltage.Layout.Row = 7; startVoltage.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Step voltage (V)');
label.Layout.Row = 8; label.Layout.Column = 1;
stepVoltage = uieditfield(controls, 'numeric', ...
    'Value', cfg.acquisition.stepVoltage, ...
    'ValueChangedFcn', @updateVoltageStatus);
stepVoltage.Layout.Row = 8; stepVoltage.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Images');
label.Layout.Row = 9; label.Layout.Column = 1;
imageCount = uieditfield(controls, 'numeric', ...
    'Value', cfg.acquisition.imageCount, ...
    'ValueChangedFcn', @updateVoltageStatus);
imageCount.Layout.Row = 9; imageCount.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Settling time (s)');
label.Layout.Row = 10; label.Layout.Column = 1;
settleTime = uieditfield(controls, 'numeric', 'Value', cfg.acquisition.settleTime);
settleTime.Layout.Row = 10; settleTime.Layout.Column = 2;

label = uilabel(controls, 'Text', 'V2 tolerance (deg)');
label.Layout.Row = 11; label.Layout.Column = 1;
phaseTolerance = uieditfield(controls, 'numeric', 'Value', cfg.processing.phaseToleranceDeg);
phaseTolerance.Layout.Row = 11; phaseTolerance.Layout.Column = 2;

label = uilabel(controls, 'Text', 'Wavelength (nm)');
label.Layout.Row = 12; label.Layout.Column = 1;
wavelength = uieditfield(controls, 'numeric', 'Value', cfg.processing.wavelengthNm);
wavelength.Layout.Row = 12; wavelength.Layout.Column = 2;

folderLabel = uilabel(controls, 'Text', 'Acquisition folder');
folderLabel.Layout.Row = 13;
folderLabel.Layout.Column = [1 2];

folderField = uieditfield(controls, 'text', 'Value', defaultFolder);
folderField.Layout.Row = 14;
folderField.Layout.Column = [1 2];

browseButton = uibutton(controls, 'Text', 'Select folder', ...
    'ButtonPushedFcn', @browseFolder);
browseButton.Layout.Row = 15;
browseButton.Layout.Column = [1 2];

acquireButton = uibutton(controls, 'Text', 'Acquire fringe scan', ...
    'Enable', 'off', 'ButtonPushedFcn', @acquireScan);
acquireButton.Layout.Row = 16;
acquireButton.Layout.Column = [1 2];

reconstructButton = uibutton(controls, 'Text', 'Reconstruct surface', ...
    'ButtonPushedFcn', @reconstructScan);
reconstructButton.Layout.Row = 17;
reconstructButton.Layout.Column = [1 2];

statusLabel = uilabel(controls, 'Text', 'Disconnected', ...
    'HorizontalAlignment', 'center');
statusLabel.Layout.Row = 18;
statusLabel.Layout.Column = [1 2];

voltageStatusLabel = uilabel(controls, ...
    'Text', 'Piezo limit: connect hardware', ...
    'HorizontalAlignment', 'center');
voltageStatusLabel.Layout.Row = 19;
voltageStatusLabel.Layout.Column = [1 2];

cameraErrorField = uitextarea(controls, 'Editable', 'off', ...
    'Value', {'Camera diagnostics: no errors'}, ...
    'Tooltip', 'Last error; history saved in data/camera_errors.log');
cameraErrorField.Layout.Row = 20;
cameraErrorField.Layout.Column = [1 2];

views = uitabgroup(main);
views.Layout.Row = 1;
views.Layout.Column = 2;

imageTab = uitab(views, 'Title', 'Interferogram');
imageGrid = uigridlayout(imageTab, [2 2]);
imageGrid.RowHeight = {'2x', '1x'};
imageGrid.ColumnWidth = {'1x', '1x'};

imageAxes = uiaxes(imageGrid);
imageAxes.Layout.Row = 1;
imageAxes.Layout.Column = [1 2];
title(imageAxes, 'Camera image - click or drag crosshair');
axis(imageAxes, 'image');
colormap(imageAxes, 'gray');

horizontalProfileAxes = uiaxes(imageGrid);
horizontalProfileAxes.Layout.Row = 2;
horizontalProfileAxes.Layout.Column = 1;
title(horizontalProfileAxes, 'Horizontal profile I(x)');
xlabel(horizontalProfileAxes, 'x (pixel)');
ylabel(horizontalProfileAxes, 'Intensity');
ylim(horizontalProfileAxes, [0 255]);

verticalProfileAxes = uiaxes(imageGrid);
verticalProfileAxes.Layout.Row = 2;
verticalProfileAxes.Layout.Column = 2;
title(verticalProfileAxes, 'Vertical profile I(y)');
xlabel(verticalProfileAxes, 'y (pixel)');
ylabel(verticalProfileAxes, 'Intensity');
ylim(verticalProfileAxes, [0 255]);

intensityTab = uitab(views, 'Title', 'Intensity');
intensityGrid = uigridlayout(intensityTab, [2 1]);
intensityGrid.RowHeight = {'1x', 42};
histAxes = uiaxes(intensityGrid);
title(histAxes, '8-bit intensity histogram');
xlabel(histAxes, 'Gray level');
ylabel(histAxes, 'Pixels');
xlim(histAxes, [0 255]);
intensityLabel = uilabel(intensityGrid, ...
    'Text', 'Mean: -   Std: -   Min: -   Max: -   Saturated: -', ...
    'HorizontalAlignment', 'center');

phaseTab = uitab(views, 'Title', 'Wrapped phase');
phaseGrid = uigridlayout(phaseTab, [1 1]);
phaseAxes = uiaxes(phaseGrid);
title(phaseAxes, 'Wrapped phase');
axis(phaseAxes, 'image');
colormap(phaseAxes, 'gray');

qualityTab = uitab(views, 'Title', 'Phase quality');
qualityGrid = uigridlayout(qualityTab, [1 1]);
qualityAxes = uiaxes(qualityGrid);
title(qualityAxes, 'PSI phase quality');
axis(qualityAxes, 'image');

surfaceTab = uitab(views, 'Title', 'Surface');
surfaceGrid = uigridlayout(surfaceTab, [1 1]);
surfaceAxes = uiaxes(surfaceGrid);
title(surfaceAxes, 'Surface v3 (nm)');

    function connectHardware(~,~)
        try
            statusLabel.Text = 'Connecting...';
            drawnow;
            piezo = psi.hardware.TPZ001Controller(cfg.hardware);
            camera = psi.hardware.DCC1545MCamera(cfg.hardware);
            previewTimer = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.1, 'TimerFcn', @updateCameraPreview, ...
                'ErrorFcn', @onPreviewTimerError);

            exposureField.Value = camera.getExposure();
            gainField.Value = camera.getGain();
            cameraFault = false;

            connectButton.Enable = 'off';
            disconnectButton.Enable = 'on';
            cameraButton.Enable = 'on';
            exposureField.Enable = 'on';
            gainField.Enable = 'on';
            applyCameraButton.Enable = 'on';
            acquireButton.Enable = 'on';
            updateVoltageStatus();
            statusLabel.Text = 'Connected';
        catch ME
            reportCameraError('Connect', ME);
            disconnectHardware();
            statusLabel.Text = 'Connection failed';
            uialert(fig, ME.message, 'Hardware connection');
        end
    end

    function disconnectHardware(varargin)
        if isAcquiring
            statusLabel.Text = 'Acquisition running: disconnect disabled';
            return
        end

        stopCameraPreview();

        if ~isempty(previewTimer)
            delete(previewTimer);
            previewTimer = [];
        end
        if ~isempty(camera)
            try
                camera.disconnect();
            catch ME
                reportCameraError('Disconnect / Exit', ME);
            end
            delete(camera);
            camera = [];
        end
        if ~isempty(piezo)
            delete(piezo);
            piezo = [];
        end

        cameraFault = false;
        connectButton.Enable = 'on';
        disconnectButton.Enable = 'off';
        cameraButton.Enable = 'off';
        exposureField.Enable = 'off';
        gainField.Enable = 'off';
        applyCameraButton.Enable = 'off';
        acquireButton.Enable = 'off';
        voltageStatusLabel.Text = 'Piezo limit: connect hardware';
        statusLabel.Text = 'Disconnected';
    end

    function toggleCameraPreview(~,~)
        if strcmp(previewTimer.Running, 'off')
            cameraButton.Text = 'Camera Off';
            statusLabel.Text = 'Camera preview';
            start(previewTimer);
        else
            stopCameraPreview();
            statusLabel.Text = 'Connected';
        end
    end

    function applyCameraSettings(~,~)
        if isAcquiring || cameraFault
            return
        end
        try
            camera.setExposure(exposureField.Value);
            camera.setGain(gainField.Value);
            exposureField.Value = camera.getExposure();
            gainField.Value = camera.getGain();
            statusLabel.Text = sprintf('Camera: %.3f ms | gain %.0f%%', ...
                exposureField.Value, gainField.Value);
        catch ME
            reportCameraError('Camera settings', ME);
            uialert(fig, ME.message, 'Camera settings');
        end
    end

    function updateCameraPreview(~,~)
        if isAcquiring || cameraFault || isempty(camera)
            return
        end
        try
            frame = camera.capture();
        catch ME
            recoverCameraAfterPreviewFailure(ME);
            return
        end
        try
            showFrame(frame);
        catch ME
            stopCameraPreview();
            reportCameraError('Preview display', ME);
            statusLabel.Text = 'Preview display failed';
            uialert(fig, ME.message, 'Preview display');
        end
    end

    function onPreviewTimerError(~, event)
        stopCameraPreview();
        try
            details = char(string(event.Data.Message));
        catch
            details = 'Unhandled timer callback error.';
        end
        ME = MException('psi:Camera:PreviewTimer', '%s', details);
        reportCameraError('Preview timer', ME);
        statusLabel.Text = 'Preview timer failed';
        uialert(fig, ME.message, 'Preview timer');
    end

    function recoverCameraAfterPreviewFailure(failure)
        stopCameraPreview();
        reportCameraError('Live view / capture', failure);

        oldCamera = camera;
        camera = [];
        try
            oldCamera.disconnect();
            delete(oldCamera);

            % Reopen only once. Leave preview off so failures remain visible.
            camera = psi.hardware.DCC1545MCamera(cfg.hardware);
            camera.setExposure(exposureField.Value);
            camera.setGain(gainField.Value);
            exposureField.Value = camera.getExposure();
            gainField.Value = camera.getGain();

            cameraFault = false;
            cameraButton.Enable = 'on';
            acquireButton.Enable = 'on';
            statusLabel.Text = 'Camera reopened; preview stopped';
            outcome = 'The camera was reopened. Press Camera On to resume.';
        catch recoveryError
            cameraFault = true;
            reportCameraError('Camera reopen', recoveryError);
            cameraButton.Enable = 'off';
            acquireButton.Enable = 'off';
            applyCameraButton.Enable = 'off';
            statusLabel.Text = 'Camera unavailable: reconnect hardware';
            outcome = sprintf('Reopen failed: %s\nUse Disconnect, then Connect.', ...
                recoveryError.message);
        end
        uialert(fig, sprintf('Preview failed: %s\n\n%s', ...
            failure.message, outcome), 'Camera SDK error');
    end

    function stopCameraPreview()
        if ~isempty(previewTimer) && isvalid(previewTimer) && ...
                strcmp(previewTimer.Running, 'on')
            stop(previewTimer);
        end
        cameraButton.Text = 'Camera On';
    end

    function showFrame(frame)
        if isempty(imageHandle) || ~isgraphics(imageHandle)
            imageHandle = imagesc(imageAxes, frame);
            imageHandle.ButtonDownFcn = @startCrosshairDrag;
            imageHandle.PickableParts = 'all';
            imageHandle.HitTest = 'on';
            axis(imageAxes, 'image');
            colormap(imageAxes, 'gray');
        else
            imageHandle.CData = frame;
        end

        updateCrosshair();
        updateIntensity(frame);
        drawnow limitrate nocallbacks;
    end

    function updateCrosshair(varargin)
        if isempty(imageHandle) || ~isgraphics(imageHandle)
            return
        end

        frame = imageHandle.CData;
        if isempty(crosshairPos)
            crosshairPos = [(size(frame,2) + 1)/2, (size(frame,1) + 1)/2];
        end

        crosshairPos(1) = min(max(crosshairPos(1), 1), size(frame,2));
        crosshairPos(2) = min(max(crosshairPos(2), 1), size(frame,1));

        if crosshairCheck.Value
            if isempty(crosshairX) || ~isgraphics(crosshairX)
                crosshairX = xline(imageAxes, crosshairPos(1), '--', ...
                    'HitTest', 'off', 'PickableParts', 'none');
                crosshairY = yline(imageAxes, crosshairPos(2), '--', ...
                    'HitTest', 'off', 'PickableParts', 'none');
            else
                crosshairX.Value = crosshairPos(1);
                crosshairY.Value = crosshairPos(2);
            end
        else
            if ~isempty(crosshairX) && isgraphics(crosshairX)
                delete(crosshairX);
            end
            if ~isempty(crosshairY) && isgraphics(crosshairY)
                delete(crosshairY);
            end
            crosshairX = [];
            crosshairY = [];
        end

        x = round(crosshairPos(1));
        y = round(crosshairPos(2));
        crosshairLabel.Text = sprintf('x: %d   y: %d', x, y);
        updateProfiles(frame);
    end

    function startCrosshairDrag(~,~)
        crosshairDragging = true;
        moveCrosshairToPointer();
        fig.WindowButtonMotionFcn = @dragCrosshair;
        fig.WindowButtonUpFcn = @stopCrosshairDrag;
    end

    function dragCrosshair(~,~)
        if crosshairDragging
            moveCrosshairToPointer();
        end
    end

    function stopCrosshairDrag(~,~)
        crosshairDragging = false;
        fig.WindowButtonMotionFcn = [];
        fig.WindowButtonUpFcn = [];
    end

    function moveCrosshairToPointer()
        if isempty(imageHandle) || ~isgraphics(imageHandle)
            return
        end

        point = imageAxes.CurrentPoint;
        frame = imageHandle.CData;
        x = min(max(point(1,1), 1), size(frame,2));
        y = min(max(point(1,2), 1), size(frame,1));
        crosshairPos = [x y];
        updateCrosshair();
        drawnow limitrate;
    end

    function updateProfiles(frame)
        x = round(crosshairPos(1));
        y = round(crosshairPos(2));

        horizontalProfile = double(frame(y,:));
        verticalProfile = double(frame(:,x));

        if isempty(horizontalProfileHandle) || ~isgraphics(horizontalProfileHandle)
            horizontalProfileHandle = plot(horizontalProfileAxes, ...
                1:size(frame,2), horizontalProfile);
            xlim(horizontalProfileAxes, [1 size(frame,2)]);
            ylim(horizontalProfileAxes, [0 255]);

            verticalProfileHandle = plot(verticalProfileAxes, ...
                1:size(frame,1), verticalProfile);
            xlim(verticalProfileAxes, [1 size(frame,1)]);
            ylim(verticalProfileAxes, [0 255]);
        else
            horizontalProfileHandle.XData = 1:size(frame,2);
            horizontalProfileHandle.YData = horizontalProfile;
            verticalProfileHandle.XData = 1:size(frame,1);
            verticalProfileHandle.YData = verticalProfile;
        end

        title(horizontalProfileAxes, sprintf('Horizontal profile I(x), y = %d', y));
        title(verticalProfileAxes, sprintf('Vertical profile I(y), x = %d', x));
    end

    function updateIntensity(frame)
        values = double(frame(:));
        counts = histcounts(values, -0.5:1:255.5);

        if isempty(histHandle) || ~isgraphics(histHandle)
            histHandle = plot(histAxes, 0:255, counts);
            xlim(histAxes, [0 255]);
        else
            histHandle.YData = counts;
        end

        saturated = 100 * nnz(frame == 255) / numel(frame);
        intensityLabel.Text = sprintf( ...
            'Mean: %.1f   Std: %.1f   Min: %d   Max: %d   Saturated: %.3f%%', ...
            mean(values), std(values), min(frame(:)), max(frame(:)), saturated);
    end

    function updateVoltageStatus(varargin)
        count = round(imageCount.Value);
        if count < 1
            voltageStatusLabel.Text = 'Invalid scan: images must be >= 1';
            return
        end

        voltages = startVoltage.Value + (0:count-1) * stepVoltage.Value;
        requestedMin = min(voltages);
        requestedMax = max(voltages);

        if isempty(piezo)
            voltageStatusLabel.Text = sprintf( ...
                'Requested scan: %.3f to %.3f V', requestedMin, requestedMax);
            return
        end

        if stepVoltage.Value > 0 && startVoltage.Value >= 0 && ...
                startVoltage.Value <= piezo.SafeMaxVoltage
            maxImages = floor((piezo.SafeMaxVoltage - startVoltage.Value) / ...
                stepVoltage.Value) + 1;
        elseif stepVoltage.Value < 0 && startVoltage.Value >= 0 && ...
                startVoltage.Value <= piezo.SafeMaxVoltage
            maxImages = floor(startVoltage.Value / abs(stepVoltage.Value)) + 1;
        else
            maxImages = Inf;
        end

        if requestedMin < 0 || requestedMax > piezo.SafeMaxVoltage
            if isfinite(maxImages)
                voltageStatusLabel.Text = sprintf( ...
                    'INVALID | %.3f to %.3f V | max images %d', ...
                    requestedMin, requestedMax, maxImages);
            else
                voltageStatusLabel.Text = sprintf( ...
                    'INVALID | %.3f to %.3f V | safe max %.3f V', ...
                    requestedMin, requestedMax, piezo.SafeMaxVoltage);
            end
        else
            if isfinite(maxImages)
                voltageStatusLabel.Text = sprintf( ...
                    'Scan %.3f to %.3f V | max images %d', ...
                    requestedMin, requestedMax, maxImages);
            else
                voltageStatusLabel.Text = sprintf( ...
                    'Scan %.3f to %.3f V | safe max %.3f V', ...
                    requestedMin, requestedMax, piezo.SafeMaxVoltage);
            end
        end
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
        if isAcquiring || cameraFault || isempty(camera)
            return
        end
        stopCameraPreview();

        acquisition = cfg.acquisition;
        acquisition.startVoltage = startVoltage.Value;
        acquisition.stepVoltage = stepVoltage.Value;
        acquisition.imageCount = round(imageCount.Value);
        acquisition.settleTime = settleTime.Value;

        isAcquiring = true;
        acquireButton.Enable = 'off';
        disconnectButton.Enable = 'off';
        reconstructButton.Enable = 'off';
        browseButton.Enable = 'off';
        cameraButton.Enable = 'off';
        exposureField.Enable = 'off';
        gainField.Enable = 'off';
        applyCameraButton.Enable = 'off';
        startVoltage.Enable = 'off';
        stepVoltage.Enable = 'off';
        imageCount.Enable = 'off';
        settleTime.Enable = 'off';
        folderField.Enable = 'off';
        statusLabel.Text = 'Acquiring...';
        drawnow limitrate nocallbacks;

        try
            psi.acquisition.acquireFringeScan(piezo, camera, acquisition, ...
                folderField.Value, @updatePreview);
            statusLabel.Text = 'Acquisition complete';
        catch ME
            statusLabel.Text = 'Acquisition failed';
            if strcmp(ME.identifier, 'psi:Acquisition:Camera')
                cameraFault = true;
                reportCameraError('Fringe scan', ME);
                statusLabel.Text = 'Camera fault: Disconnect / Connect';
            end
            uialert(fig, ME.message, 'Acquisition');
        end

        isAcquiring = false;
        disconnectButton.Enable = 'on';
        reconstructButton.Enable = 'on';
        browseButton.Enable = 'on';
        startVoltage.Enable = 'on';
        stepVoltage.Enable = 'on';
        imageCount.Enable = 'on';
        settleTime.Enable = 'on';
        folderField.Enable = 'on';
        cameraButton.Enable = onOff(~cameraFault);
        exposureField.Enable = onOff(~cameraFault);
        gainField.Enable = onOff(~cameraFault);
        applyCameraButton.Enable = onOff(~cameraFault);
        acquireButton.Enable = onOff(~cameraFault);
    end

    function updatePreview(frame, index, count, commanded, measured)
        showFrame(frame);
        statusLabel.Text = sprintf('%d/%d | %.3f V -> %.3f V', ...
            index, count, commanded, measured);
        drawnow limitrate nocallbacks;
    end

    function reconstructScan(~,~)
        if isAcquiring
            return
        end
        processing = cfg.processing;
        processing.phaseToleranceDeg = phaseTolerance.Value;
        processing.wavelengthNm = wavelength.Value;

        statusLabel.Text = 'Reconstructing...';
        drawnow;

        try
            result = psi.processing.reconstructSurface( ...
                folderField.Value, processing);

            imagesc(phaseAxes, result.filteredWrappedPhase);
            axis(phaseAxes, 'image');
            colormap(phaseAxes, 'gray');
            title(phaseAxes, 'Filtered wrapped phase');

            imagesc(qualityAxes, result.qualityMap, [0 1]);
            axis(qualityAxes, 'image');
            colorbar(qualityAxes);

            surf(surfaceAxes, result.surfaceNm, 'EdgeColor', 'none');
            axis(surfaceAxes, 'tight');
            view(surfaceAxes, 3);
            xlabel(surfaceAxes, 'x (pixel)');
            ylabel(surfaceAxes, 'y (pixel)');
            zlabel(surfaceAxes, 'height (nm)');
            colorbar(surfaceAxes);

            validPercent = 100 * nnz(result.validMask) / numel(result.validMask);
            statusLabel.Text = sprintf( ...
                'Reconstruction v3 | %d frames | phase span %.1f deg | valid %.1f%%', ...
                result.imageCount, result.phaseSpanDeg, validPercent);
        catch ME
            statusLabel.Text = 'Reconstruction failed';
            uialert(fig, ME.message, 'Reconstruction');
        end
    end

    function reportCameraError(context, ME)
        stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
        cameraErrorField.Value = {sprintf('[%s] %s', stamp, context), ...
            sprintf('%s: %s', ME.identifier, ME.message)};

        try
            logFolder = fullfile(root, 'data');
            if ~isfolder(logFolder)
                mkdir(logFolder);
            end
            fid = fopen(fullfile(logFolder, 'camera_errors.log'), 'a');
            if fid >= 0
                message = strrep(ME.message, newline, ' | ');
                fprintf(fid, '[%s] %s | %s | %s\n', ...
                    stamp, context, ME.identifier, message);
                fclose(fid);
            end
        catch
            % Diagnostic logging must not mask the camera failure.
        end
    end

    function state = onOff(condition)
        if condition
            state = 'on';
        else
            state = 'off';
        end
    end

    function closeApp(~,~)
        if isAcquiring
            statusLabel.Text = 'Finish acquisition before closing';
            return
        end
        disconnectHardware();
        delete(fig);
    end
end
