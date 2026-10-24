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
- Quality map, circular phase filtering, quality-aware unwrapping, 2-D tilt removal, and phase-to-surface conversion.
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
7. Perform quality-aware phase unwrapping.
8. Fit and remove a weighted 2-D tilt plane.
9. Convert reflected optical phase to height with `h = lambda*phi/(4*pi)`.

The V2 four-frame and legacy results are also stored when four approximately 90-degree-separated frames can be identified.

## Processing defaults

- Circular phase-filter radius: 2 pixels
- Quality threshold: 0.10
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
