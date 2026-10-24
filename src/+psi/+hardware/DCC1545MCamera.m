classdef DCC1545MCamera < handle
    properties (SetAccess = private)
        Camera
        MemoryId
        Width
        Height
        Bits
        LastError = ""
        LastErrorTime = []
    end

    methods
        function obj = DCC1545MCamera(hardwareConfig)
            NET.addAssembly(hardwareConfig.cameraDll);
            obj.Camera = uc480.Camera;

            try
                obj.checkStatus(obj.Camera.Init(0), 'Init');
                obj.checkStatus(obj.Camera.Display.Mode.Set( ...
                    uc480.Defines.DisplayMode.DiB), 'Display.Mode.Set');
                obj.checkStatus(obj.Camera.PixelFormat.Set( ...
                    uc480.Defines.ColorMode.RGBA8Packed), 'PixelFormat.Set');
                obj.checkStatus(obj.Camera.Trigger.Set( ...
                    uc480.Defines.TriggerMode.Software), 'Trigger.Set');

                [status, obj.MemoryId] = obj.Camera.Memory.Allocate(true);
                obj.checkStatus(status, 'Memory.Allocate');

                [status, width, height, bits, ~] = ...
                    obj.Camera.Memory.Inquire(obj.MemoryId);
                obj.checkStatus(status, 'Memory.Inquire');

                obj.Width = double(width);
                obj.Height = double(height);
                obj.Bits = double(bits);
            catch ME
                % Init may have succeeded before a later setup call failed.
                if ~isempty(obj.Camera)
                    try
                        exitStatus = obj.Camera.Exit();
                        if ~strcmp(char(exitStatus.ToString()), 'SUCCESS')
                            ME = addCause(ME, MException('psi:Camera:Cleanup', ...
                                'Camera Exit after failed initialization: %s', ...
                                char(exitStatus.ToString())));
                        end
                    catch cleanupError
                        ME = addCause(ME, cleanupError);
                    end
                    obj.Camera = [];
                end
                rethrow(ME);
            end
        end

        function frame = capture(obj)
            % Retry one transient SDK failure. Never return a stale frame.
            for attempt = 1:2
                try
                    obj.requireOpen();
                    status = obj.Camera.Acquisition.Freeze( ...
                        uc480.Defines.DeviceParameter.Wait);
                    obj.checkStatus(status, 'Acquisition.Freeze');

                    [status, data] = obj.Camera.Memory.CopyToArray(obj.MemoryId);
                    obj.checkStatus(status, 'Memory.CopyToArray');

                    data = reshape(uint8(data), ...
                        [obj.Bits/8, obj.Width, obj.Height]);
                    frame = squeeze(data(1,:,:)).';
                    return
                catch ME
                    obj.rememberError(ME);
                    if attempt == 1 && strcmp(ME.identifier, 'psi:Camera:Transient')
                        pause(0.1);
                    else
                        rethrow(ME);
                    end
                end
            end
        end

        function setExposure(obj, exposureMs)
            obj.requireOpen();
            obj.checkStatus(obj.Camera.Timing.Exposure.Set( ...
                double(exposureMs)), 'Timing.Exposure.Set');
        end

        function exposureMs = getExposure(obj)
            obj.requireOpen();
            [status, exposureMs] = obj.Camera.Timing.Exposure.Get();
            obj.checkStatus(status, 'Timing.Exposure.Get');
            exposureMs = double(exposureMs);
        end

        function setGain(obj, gainPercent)
            obj.requireOpen();
            obj.checkStatus(obj.Camera.Gain.Hardware.Scaled.SetMaster( ...
                int32(gainPercent)), 'Gain.Hardware.Scaled.SetMaster');
        end

        function gainPercent = getGain(obj)
            obj.requireOpen();
            [status, gainPercent] = obj.Camera.Gain.Hardware.Scaled.GetMaster();
            obj.checkStatus(status, 'Gain.Hardware.Scaled.GetMaster');
            gainPercent = double(gainPercent);
        end

        function disconnect(obj)
            if isempty(obj.Camera)
                return
            end

            obj.checkStatus(obj.Camera.Exit(), 'Exit');
            obj.Camera = [];
        end

        function delete(obj)
            if isempty(obj.Camera)
                return
            end
            try
                obj.disconnect();
            catch ME
                warning('psi:Camera:CleanupFailed', '%s', ME.message);
            end
        end
    end

    methods (Access = private)
        function requireOpen(obj)
            if isempty(obj.Camera) || ~logical(obj.Camera.IsOpened)
                ME = MException('psi:Camera:NotOpen', ...
                    'Camera is not open (device unplugged or driver handle invalid).');
                obj.rememberError(ME);
                throw(ME);
            end
        end

        function checkStatus(obj, status, operation)
            code = char(status.ToString());
            if strcmp(code, 'SUCCESS')
                return
            end

            switch code
                case {'TIMED_OUT', 'TRANSFER_ERROR', 'DEVICE_BUSY'}
                    identifier = 'psi:Camera:Transient';
                otherwise
                    identifier = 'psi:Camera:SDK';
            end

            detail = '';
            switch code
                case 'TIMED_OUT'
                    detail = 'Capture did not finish before the SDK timeout.';
                case 'TRANSFER_ERROR'
                    detail = 'Image transfer failed; inspect USB link and pixel rate.';
                case {'DEVICE_BUSY', 'ALL_DEVICES_BUSY'}
                    detail = 'Camera is busy or owned by another process.';
                case 'IO_REQUEST_FAILED'
                    detail = 'Driver I/O failed; verify SDK and USB driver versions.';
                case {'INVALID_CAMERA_HANDLE', 'CANT_OPEN_DEVICE', ...
                        'CANT_COMMUNICATE_WITH_DRIVER'}
                    detail = 'Camera handle or driver communication is unavailable.';
            end

            ME = MException(identifier, ...
                'Camera %s failed [%s]. %s', operation, code, detail);
            obj.rememberError(ME);
            throw(ME);
        end

        function rememberError(obj, ME)
            obj.LastError = string(ME.message);
            obj.LastErrorTime = datetime('now');
        end
    end
end
