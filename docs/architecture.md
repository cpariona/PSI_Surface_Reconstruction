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

### Interactive processing and reference correction

The GUI displays raw/filtered wrapped phase, quality and a mask classifying
excluded, valid and isolated-spike pixels. Its numeric controls do not
recompute on change: only `Apply processing` invokes
`psi.processing.reprocessSurface` using the cached multi-frame PSI
phase/quality. This backend recomputes the circular filter, quality-guided
2-D unwrap, spike rejection, robust tilt fit and height. Its results and
parameter values are saved in `reconstruction.mat`.

`Draw reference ROI` uses an editable `images.roi.Rectangle` on
`uiaxes`. The `ROIClicked` event with `SelectionType='double'`
confirms the current rectangle. Only then does the GUI call
`psi.processing.relevelSurface`, which refits the reference tilt without
recomputing the PSI or unwrap. `ROIMoved` marks unconfirmed ROI edits
as pending. `Full field` explicitly clears the ROI.

All scientific processing remains in `src/+psi/+processing` per
`AGENTS.md`; the UI only collects settings, handles ROI events,
presents diagnostics and dispatches processing calls. Camera and piezo
APIs are unchanged.

Unwrapping uses quality-masked connectivity. Disconnected islands have
no shared phase origin and are omitted; changes larger than pi radians
between neighboring pixels or errors in estimated PSI phase steps
still require additional experimental diagnosis.
