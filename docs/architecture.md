# Architecture

The repository has one maintained backend under `src/+psi`.

```text
GUI / workflows
      |
      +--> +hardware      TPZ001 and DCC1545M access
      +--> +acquisition   voltage scan -> image capture -> BMP + metadata
      +--> +processing    frame selection -> PSI -> stabilization -> surface
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

The DCC1545M uses the validated `uc480DotNet.dll` path and `RGBA8Packed` acquisition. Only the first channel is retained because the camera is monochrome. Exposure and master gain are controlled through the same DCx .NET interface and are held fixed during a fringe scan.

## Processing

Frame selection and four-step PSI remain unchanged from v1 so that v2 isolates the surface-reconstruction changes.

### Legacy path

1. Estimate fringe spatial frequency from a horizontal profile.
2. Use cross-correlation to find four frames separated by approximately 90 degrees.
3. Compute wrapped phase with the four-step PSI equation.
4. Unwrap across rows and columns.
5. Remove the measured linear carrier and reference offset.
6. Convert reflected optical phase to surface height with `h = lambda*phi/(4*pi)`.

### V2 path

1. Compute wrapped phase from the same four selected interferograms.
2. Compute a normalized modulation-based quality map. Saturated pixels receive zero quality.
3. Smooth the wrapped phase as a complex phasor, weighted by the quality map.
4. Unwrap each row and align neighboring rows using reliable vertical phase differences.
5. Fit a weighted 2-D plane to the unwrapped phase and subtract it as interferometric tilt.
6. Convert the corrected phase to surface height with `h = lambda*phi/(4*pi)`.

The v2 result is returned as `result.surfaceNm`. The previous reconstruction is retained as `result.legacySurfaceNm` for direct comparison.
