classdef TPZ001Controller < handle
    properties (SetAccess = private)
        Serial
        Device
        MaxVoltage
        OriginalSource
        OriginalMode
    end

    methods
        function obj = TPZ001Controller(hardwareConfig)
            obj.Serial = hardwareConfig.piezoSerial;
            kinesis = hardwareConfig.kinesisPath;

            NET.addAssembly(fullfile(kinesis, ...
                'Thorlabs.MotionControl.DeviceManagerCLI.dll'));
            NET.addAssembly(fullfile(kinesis, ...
                'Thorlabs.MotionControl.GenericPiezoCLI.dll'));
            NET.addAssembly(fullfile(kinesis, ...
                'Thorlabs.MotionControl.TCube.PiezoCLI.dll'));

            import Thorlabs.MotionControl.DeviceManagerCLI.*
            import Thorlabs.MotionControl.TCube.PiezoCLI.*

            DeviceManagerCLI.BuildDeviceList();
            obj.Device = TCubePiezo.CreateTCubePiezo(obj.Serial);
            obj.Device.Connect(obj.Serial);

            if ~obj.Device.IsSettingsInitialized()
                obj.Device.WaitForSettingsInitialized(5000);
            end

            obj.Device.StartPolling(250);
            pause(0.5);
            obj.Device.EnableDevice();
            pause(0.5);

            obj.Device.GetPiezoConfiguration(obj.Serial);

            obj.OriginalSource = obj.Device.GetVoltageSource();
            obj.OriginalMode = obj.Device.GetPositionControlMode();

            sourceType = obj.OriginalSource.GetType();
            softwareSource = System.Enum.Parse(sourceType, 'SoftwareOnly');
            obj.Device.SetVoltageSource(softwareSource);

            modeType = obj.OriginalMode.GetType();
            openLoop = System.Enum.Parse(modeType, 'OpenLoop');
            obj.Device.SetPositionControlMode(openLoop);

            obj.MaxVoltage = System.Decimal.ToDouble( ...
                obj.Device.GetMaxOutputVoltage());

            obj.setVoltage(0);
            pause(0.1);
        end

        function setVoltage(obj, voltage)
            if voltage < 0 || voltage > obj.MaxVoltage
                error('Voltage must be between 0 and %.3f V.', obj.MaxVoltage);
            end
            obj.Device.SetOutputVoltage(System.Decimal(voltage));
        end

        function voltage = readVoltage(obj)
            voltage = System.Decimal.ToDouble(obj.Device.GetOutputVoltage());
        end

        function disconnect(obj)
            if isempty(obj.Device)
                return
            end

            obj.setVoltage(0);
            pause(0.1);
            obj.Device.SetPositionControlMode(obj.OriginalMode);
            obj.Device.SetVoltageSource(obj.OriginalSource);
            obj.Device.StopPolling();
            obj.Device.Disconnect(true);
            obj.Device = [];
        end

        function delete(obj)
            try
                obj.disconnect();
            catch
            end
        end
    end
end
