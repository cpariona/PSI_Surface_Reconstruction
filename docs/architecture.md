# Architecture

The repository has one maintained backend under `src/+psi`.

```text
GUI / workflows
      |
      +--> +hardware      TPZ001 and DCC1545M access
      +--> +acquisition   validate scan -> voltage scan -> BMP + metadata
      +--> +processing    phase-step estimation -> multi-frame PSI -> surface
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

The controller-reported maximum output is stored as `MaxVoltage`. The maintained command limit is `SafeMaxVoltage`, defined as the lower of the controller limit and the optional configured actuator limit. The complete requested voltage vector is validated before an acquisition starts, and `setVoltage` independently rejects an individual out-of-range command.

The application returns the commanded voltage to zero and restores the original TPZ001 source/mode when it disconnects.

The DCC1545M uses the validated `uc480DotNet.dll` path and `RGBA8Packed` acquisition. Only the first channel is retained because the camera is monochrome. Exposure and master gain are controlled through the same DCx .NET interface and are held fixed during a fringe scan.

## Processing

### V3 maintained path

1. Estimate fringe spatial frequency from a horizontal profile.
2. Measure the relative phase step of every interferogram from the complex FFT coefficient at the fringe carrier.
3. Use every acquired image in a least-squares PSI model:
   `I_k = A + C*cos(delta_k) + S*sin(delta_k)`.
4. Recover wrapped phase as `atan2(-S,C)`.
5. Compute a normalized modulation-based quality map. Saturated pixels receive zero quality.
6. Smooth the wrapped phase as a complex phasor weighted by quality.
7. Unwrap phase on a maximum-reliability 2-D pixel spanning forest. Only the largest connected reliable component is retained.
8. Reject isolated phase spikes by local-neighbor agreement; rejected pixels remain NaN.
9. Fit a robust weighted 2-D plane using only reliable pixels inside the selected flat reference ROI; subtract it across the valid surface.
10. Convert corrected phase to surface height with `h = lambda*phi/(4*pi)` (unreliable pixels remain NaN).

### Comparison outputs

When four approximately 90-degree-separated frames can still be selected, the reconstruction file also stores:

- `v2SurfaceNm`: the V2 four-frame reconstruction with quality filtering and 2-D tilt removal.
- `legacySurfaceNm`: the original sequential unwrap and linear-carrier reconstruction.

The primary maintained result is `result.surfaceNm` from V3.

### Interactive reference correction

`app/PSISurfaceApp.m` accepts the reference rectangle using two clicks
on the quality view. The GUI invokes `psi.processing.relevelSurface`, which
reuses stored unwrapped phase, calls `removeTiltPlane` and
`phaseToSurface`, and persists `reconstruction.mat`. It does not duplicate
phase processing in the GUI. The legacy output is intentionally unchanged,
and the V2 comparison is relevelled when available.

Unwrapping uses quality-masked neighborhood connectivity; disconnected
islands have no common phase origin and are omitted rather than being
artificially aligned. A large phase gradient over pi rad/pixel or a phase
step error upstream remains outside the guarantee of this method.
