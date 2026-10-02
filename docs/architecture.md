# Architecture

The repository has one maintained backend under `src/+psi`.

```text
GUI / workflows
      |
      +--> +hardware      TPZ001 and DCC1545M access
      +--> +acquisition   voltage scan -> image capture -> BMP + metadata
      +--> +processing    frame selection -> PSI -> unwrap -> carrier -> surface
```

## Hardware ownership

`TPZ001Controller` owns the Kinesis connection and `DCC1545MCamera` owns the DCx camera connection. The GUI and workflows only call their public methods.

The TPZ001 initialization sequence is based on the sequence validated on the physical controller:

```text
BuildDeviceList
CreateTCubePiezo
Connect
WaitForSettingsInitialized
StartPolling
EnableDevice
GetPiezoConfiguration
SoftwareOnly + OpenLoop
SetOutputVoltage
```

The application returns the commanded voltage to zero and restores the original TPZ001 source/mode when it disconnects.

The DCC1545M uses the validated `uc480DotNet.dll` path and `RGBA8Packed` acquisition. Only the first channel is retained because the camera is monochrome.

## Processing

The first version follows the legacy MATLAB workflow:

1. Estimate fringe spatial frequency from a horizontal profile.
2. Use cross-correlation to find four frames separated by approximately 90 degrees.
3. Compute wrapped phase with the four-step PSI equation.
4. Unwrap across rows and columns.
5. Remove the linear carrier and reference offset.
6. Convert reflected optical phase to surface height with `h = lambda*phi/(4*pi)`.

The carrier frequency used for removal is the frequency measured from the acquired data rather than the fixed legacy value of 4 fringes per image.
