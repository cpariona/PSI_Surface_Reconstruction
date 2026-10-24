# PSI Surface Reconstruction

MATLAB implementation of the phase-shifting interferometry (PSI) system previously split between LabVIEW acquisition and MATLAB processing.

The current version integrates:

- Thorlabs TPZ001 piezo controller through Kinesis .NET.
- Thorlabs DCC1545M camera through the DCx `uc480DotNet.dll` interface.
- Live camera preview with exposure, gain, histogram, saturation statistics, movable crosshair, and horizontal/vertical intensity profiles.
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
10. Convert reflected optical phase to height with `h = lambda*phi/(4*pi)`.

The V2 four-frame and legacy results are also stored when four approximately 90-degree-separated frames can be identified.

## Processing defaults

- Circular phase-filter radius: 2 pixels
- Quality threshold: 0.10
- Isolated-spike threshold: pi radians
- Tilt reference ROI: [] (whole field until a reference is selected)
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

## Phase noise filtering and tilt

After multi-frame PSI, the **phase quality map** gives low weight to regions
with weak modulation or saturated pixels. V3 filters wrapped phase as a complex
phasor:

```text
z = exp(1i*wrappedPhase)
filtered = angle(conv2(quality.^2 .* z, kernel, 'same') ...
                 ./ conv2(quality.^2, kernel, 'same'))
```

The default `filterRadius = 2` gives a 5-by-5 pixel box kernel. Raising
this radius smooths more noise but can erase fine surface details.

After unwrapping, the tilt correction fits a quality-weighted 2-D phase plane
`a*x + b*y + c` and subtracts it before conversion to nanometers.
`qualityThreshold = 0.10` defines which pixels enter the plane fit and
guide row alignment. Both parameters are set in
`config/system_config.m` and are applied automatically during reconstruction.

**Important limitation:** the current plane fit uses all high-quality pixels,
not a user-selected flat reference ROI. If the sample is curved or has a
significant intrinsic slope, a whole-field plane fit can remove part of the
true surface shape. Validate tilt removal against a known reference or adapt
the reference region before quantitative measurements.

## Selecting a flat reference ROI

After `Reconstruct surface`, open `Phase quality`, press
`Select flat reference ROI` and click **two opposite corners** on the quality
image. The ROI must contain a physically flat region with at least 25 reliable
pixels and 2-D coverage. The backend recalculates the plane from that ROI,
updates the surface without rereading the scan, and saves the new
`reconstruction.mat`. `Use full field` resets the reference selection.

The full-field default is only a convenient initial view. It can remove part
of a sample's real slope/shape. Do not assume that a high-quality image region
is geometrically flat. A new scan resets any old interactive ROI.

The saved result includes `unwrapDiagnostics`, `unwrapMask`,
`spikeMask`, `referenceMask`, `tiltPlane`, `tiltCoefficients`,
`processing.tiltROI`, `surfaceNm`, and the preserved comparison surfaces.
Holes in the surface indicate missing/low-confidence data, **not zero height**.

The quality-guided unwrapping assumes neighboring valid pixels have true
phase differences smaller than pi. A discontinuity beyond this sampling
condition cannot be recovered unambiguously from PSI alone. The phase steps
in V3 are still estimated from one selected fringe profile; their accuracy
must be checked with measured data.
