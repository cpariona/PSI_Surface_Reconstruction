# PSI Surface Reconstruction

MATLAB implementation of the phase-shifting interferometry (PSI) system previously split between LabVIEW acquisition and MATLAB processing.

The current version integrates:

- Thorlabs TPZ001 piezo controller through Kinesis .NET.
- Thorlabs DCC1545M camera through the DCx `uc480DotNet.dll` interface.
- Live camera preview with exposure, gain, histogram, saturation statistics, a solid white crosshair, and horizontal/vertical intensity profiles.
- Voltage scan and interferogram acquisition with pre-scan voltage validation.
- Controller-reported voltage limit plus an optional actuator-specific voltage limit.
- Multi-frame PSI v3 using all acquired interferograms.
- Automatic estimation of the actual phase step of each interferogram from the fringe carrier.
- Quality map, circular phase filtering, quality-guided 2-D phase unwrapping, isolated-spike rejection, and reference-based 2-D tilt removal.
- V2 and legacy reconstruction outputs retained when available for comparison.
- A MATLAB GUI that calls the same backend used by the command-line workflows.

## Requirements

- Windows 11.
- MATLAB R2025b or newer.
- Image Processing Toolbox for the editable `drawrectangle` reference ROI.
- Thorlabs Kinesis installed in `C:\Program Files\Thorlabs\Kinesis`.
- Thorlabs DCx Camera Support / ThorCam installed.
- TPZ001, serial number `81857565`.
- DCC1545M camera.

Close Kinesis and ThorCam before connecting from MATLAB so that MATLAB has exclusive access to the hardware.

## Start the GUI

From the repository root:

```matlab
addpath('app')
PSISurfaceApp
```

The GUI adds `src` and `config` to the MATLAB path automatically.

## Default acquisition

- Start voltage: 0 V
- Step: 0.1 V
- Images: 85
- Settling time: 0.5 s
- Wavelength: 660 nm

Before acquisition, the complete voltage vector is checked against `piezo.SafeMaxVoltage`. The safe limit is the controller-reported maximum, or the lower actuator limit when `cfg.hardware.actuatorMaxVoltage` is configured.

## PSI reconstruction

V3 is the maintained reconstruction path:

1. Estimate the fringe carrier from the analysis row.
2. Estimate the relative phase of every acquired interferogram from that carrier.
3. Solve `I_k = A + C*cos(delta_k) + S*sin(delta_k)` by least squares using all images.
4. Recover wrapped phase from `atan2(-S,C)`.
5. Build a modulation-based quality map.
6. Filter the wrapped phase in the complex domain.
7. Unwrap phase on a quality-weighted 2-D pixel graph; retain only its largest connected component.
8. Mask isolated phase spikes; unreliable regions remain NaN in the height surface.
9. Robustly fit and remove a 2-D tilt plane using a flat reference ROI.
10. Convert reflected optical phase to height with `h = p*lambda*phi/(4*pi)`, where `p` is the calibrated height polarity (+1/-1).

The V2 four-frame and legacy results are also stored when four approximately 90-degree-separated frames can be identified.

## Processing defaults

- Circular phase-filter radius: 2 pixels
- Quality threshold: 0.10
- Isolated-spike threshold: pi radians
- Tilt reference ROI: [] (whole field until a reference is selected)
- V2 comparison: disabled by default (`computeV2Comparison = false`).
- Fast uncompressed MAT saving: enabled (`fastSave = true`; larger files).
- Surface 3-D preview maximum dimension: 350 samples.
- Height polarity: automatic, using signed temporal movement of the fringe carrier; manually overridable.
- V2 phase-step target: 90 degrees
- V2 phase-step tolerance: 5 degrees

These values are in `config/system_config.m`.

## Command-line workflows

```matlab
addpath('workflows')
scan = run_fringe_scan('data/my_scan');
result = run_surface_reconstruction('data/my_scan');
```

## Structure

```text
app/                    GUI
config/                 Physical and acquisition parameters
src/+psi/+hardware/     TPZ001 and DCC1545M interfaces
src/+psi/+acquisition/  Voltage scan and image acquisition
src/+psi/+processing/   PSI and surface reconstruction
workflows/              Minimal command-line entry points
docs/                   Architecture notes
```

Acquired data are written under `data/` by default and are not versioned.

## Camera errors and recovery

Camera SDK operations now report the actual SDK status and operation (for example,
`Camera Acquisition.Freeze failed [TIMED_OUT]`). The GUI displays the most
recent issue in its diagnostics text area. It also appends timestamped errors to
`data/camera_errors.log`, including transient errors that succeed on retry.

- `TIMED_OUT`: no image arrived within the SDK timeout.
- `TRANSFER_ERROR`: image transfer failed; examine the USB path and camera pixel rate.
- `DEVICE_BUSY` / `ALL_DEVICES_BUSY`: the camera is busy or in use elsewhere.
- `IO_REQUEST_FAILED`: driver I/O failure; verify SDK/driver compatibility.
- `INVALID_CAMERA_HANDLE` / `CANT_OPEN_DEVICE`: the handle or connection is unavailable.

A capture retries **once** for `TIMED_OUT`, `TRANSFER_ERROR`, or
`DEVICE_BUSY`. If live preview still fails, the GUI stops preview and attempts
one complete camera reopen while preserving exposure and gain. Even if it
reopens successfully, preview does not restart until the operator presses
`Camera On`. A failed reopen requires `Disconnect` then `Connect`.

A camera error during a voltage scan aborts that scan. The piezo is returned
to the commanded 0 V through the existing cleanup. Any BMPs already written
are a **partial scan** and should not be reconstructed as if complete.

These SDK codes identify failure categories, not necessarily the physical cause.
For recurring failures, inspect the recorded operation/status and check the USB
cable, port, driver versions and whether ThorCam is closed.

## Phase quality: explicit processing

The `Phase quality` tab displays four synchronized diagnostics:

- **Phase quality / reference ROI**: PSI modulation-based confidence map.
- **Mask**: 0 = excluded, 1 = valid, 2 = isolated spike rejected.
- **Raw wrapped phase**: phase before the spatial noise filter.
- **Filtered wrapped phase**: phase after circular noise filtering.

The three controls are:

- `Noise radius (px)`: circular spatial-filter radius. A value of 2 is a
  5-by-5 window. Larger radii suppress more detail along with noise.
- `Quality threshold`: threshold for graph-based 2-D unwrapping and the
  robust tilt fit; zero-quality pixels are always excluded.
- `Spike threshold (rad)`: local-neighbor deviation needed to reject an
  isolated spike in the unwrapped phase (default `pi`).

Editing a value displays **Pending changes**; nothing is recalculated yet.
Click **Apply processing** to update the affected stages using the cached
multi-frame PSI phase. A spike-threshold change skips filtering and
unwrapping; a quality-threshold change skips filtering but reruns unwrap.
The camera BMPs are not reread. The quality/mask views report valid pixels
and rejected spikes; a line below the views reports measured seconds for
filtering, unwrapping, spike detection, tilt fitting and MAT saving.

`Reconstruct surface`, `Apply processing`, and tilt-only ROI leveling
run in MATLAB `backgroundPool`, so the app remains responsive while
numeric work runs. MATLAB includes one background worker even without
Parallel Computing Toolbox. Hardware controls are disabled during
background processing. The default 3-D preview is downsampled for
rendering only; stored surfaces retain native resolution.

Full-field unwrapping uses native compiled `graph`/`minspantree`/
`dfsearch` instead of millions of interpreted union-find operations.
The core quality weights and largest-connected-component rule are
retained, though tie resolution in the spanning tree may differ.

For performance, the expensive V2 comparison is **opt-in**:
set `cfg.processing.computeV2Comparison = true` before reconstructing.
The fast default skips v2 and legacy comparisons; historical outputs
remain in any older saved reconstruction files. Fast MAT saving uses
`-nocompression`, which shortens compression overhead at the expense
of larger `reconstruction.mat` files.

### Editable reference ROI

After reconstructing, press **Draw reference ROI**. Drag a rectangle on
the **Phase quality / reference ROI** image. Move or resize the rectangle
as needed, then **double-click inside** it to confirm and relevel the
surface. The rectangle remains on the image. Moving it marks the tilt
reference pending until you double-click again. Press **Full field**
to remove the ROI and fit a plane to all reliable pixels instead.

Confirming an ROI recalculates **only the 2-D robust tilt fit and surface**;
it does not rerun the spatial filter or unwrap. The ROI must cover at
least 25 reliable pixels with meaningful 2-D spatial extent. Selecting
a different acquisition folder requires a new reconstruction before
processing controls can operate on its data.

The `Before / after tilt` tab compares the original unwrapped height
and the levelled height. All rejected and low-quality pixels remain
`NaN` (missing data), never interpolated or silently set to zero.

**Scientific limitation:** the ROI must be a *physically planar
reference*, not merely a high-contrast region. A full-field plane fit
may remove real specimen geometry. True phase steps exceeding pi per
pixel are ambiguous even with quality-guided unwrapping; verify surface
height against a measured reference.

The backend `psi.processing.reprocessSurface` owns parameter-driven
phase filtering and saving; `psi.processing.relevelSurface` owns
reference-only leveling. The GUI is limited to user input and display.

## Synthetic reconstruction check

A focused check for 2-D unwrap continuity, isolated spike masking,
reference-plane recovery, cached-stage reuse and ROI leveling is at
`tests/test_reconstruction_synthetic.m`. With MATLAB available:

```matlab
addpath('tests')
test_reconstruction_synthetic
```

The check does not use physical hardware and does not establish optical
measurement accuracy. Experimental comparison with a flat reference is
required before interpreting surface heights quantitatively.

## Calibrated fringe direction and height polarity (PSI v3)

The multi-frame fit remains `I_k = A + C*cos(delta_k) + S*sin(delta_k)`
with wrapped phase `phi = atan2(-S,C)`. Its temporal phase steps
`delta_k` are measured from the positive-frequency spatial FFT carrier.
When that phase increases with acquisition index, fringes move **left** in
the camera image. When it decreases, they move **right**. By the observed
calibration of this optical setup, the v3 height polarity is:

- Leftward fringes: `p = +1` (keep reconstructed height sign).
- Rightward fringes: `p = -1` (invert reconstructed height sign).

The correction multiplies **the final v3 height**, after phase unwrapping
and planar tilt correction. It does not alter the wrapped-phase model or
repeat costly unwrapping. `relevelSurface` retains the same polarity
when a different reference ROI is selected. The before/after tilt view
also uses the same calibrated height sign.

Default: `cfg.processing.heightPolarity = []` (automatic). If the
fringe motion is inconsistent or too small to detect reliably, the
reconstruction stops with an explanation instead of guessing. The
operator can set `cfg.processing.heightPolarity = +1` or `-1` to use
a calibrated manual sign. This is a **mount-specific calibration**:
changing camera orientation or optical geometry can invalidate the
left/right-to-height mapping.

The result MAT file records `result.fringeDirection`,
`result.heightPolarity` and `result.fringeMotion` without adding new
GUI elements. When present, the optional PSI v2/legacy comparisons
retain their original phase conventions; the automatic sign calibration
is applied to the maintained **v3** surface.

### PSI v2 versus PSI v3

PSI v2 selects four approximately quadrature-spaced images, forms
`a = I1-I3`, `b = I4-I2` and computes `phi2 = atan2(a,b)`.
This assumes the selected images have the requisite quarter-cycle
separations; its phase convention is not identical to v3's.

PSI v3 uses all images. After estimating each measured step `delta_k`,
it solves the three-parameter per-pixel least-squares model
`I_k = A + C*cos(delta_k) + S*sin(delta_k)`. It then computes
`phi3 = atan2(-S,C)`. Both methods perform phase filtering, unwrapping,
spike rejection and tilt removal before phase-to-height conversion.
PSI v3 generally uses more measurements to reduce random phase noise
and does not force all phase steps to be exactly 90 degrees.
