classdef DCC1545MCamera < handle
    properties (SetAccess = private)
        Camera
        MemoryId
        Width
        Height
        Bits
    end

    methods
        function obj = DCC1545MCamera(hardwareConfig)
            NET.addAssembly(hardwareConfig.cameraDll);

            obj.Camera = uc480.Camera;
            status = obj.Camera.Init(0);
            if ~strcmp(char(status.ToString()), 'SUCCESS')
                error('Could not initialize DCC1545M camera.');
            end

            obj.Camera.Display.Mode.Set(uc480.Defines.DisplayMode.DiB);
            obj.Camera.PixelFormat.Set(uc480.Defines.ColorMode.RGBA8Packed);
            obj.Camera.Trigger.Set(uc480.Defines.TriggerMode.Software);

            [status, obj.MemoryId] = obj.Camera.Memory.Allocate(true);
            if ~strcmp(char(status.ToString()), 'SUCCESS')
                error('Could not allocate camera image memory.');
            end

            [~, width, height, bits, ~] = ...
                obj.Camera.Memory.Inquire(obj.MemoryId);
            obj.Width = double(width);
            obj.Height = double(height);
            obj.Bits = double(bits);
        end

        function frame = capture(obj)
            status = obj.Camera.Acquisition.Freeze( ...
                uc480.Defines.DeviceParameter.Wait);
            if ~strcmp(char(status.ToString()), 'SUCCESS')
                error('Camera acquisition failed.');
            end

            [status, data] = obj.Camera.Memory.CopyToArray(obj.MemoryId);
            if ~strcmp(char(status.ToString()), 'SUCCESS')
                error('Could not copy camera image to MATLAB.');
            end

            data = reshape(uint8(data), ...
                [obj.Bits/8, obj.Width, obj.Height]);
            frame = squeeze(data(1,:,:)).';
        end

        function disconnect(obj)
            if isempty(obj.Camera)
                return
            end
            obj.Camera.Exit();
            obj.Camera = [];
        end

        function delete(obj)
            try
                obj.disconnect();
            catch
            end
        end
    end
end
