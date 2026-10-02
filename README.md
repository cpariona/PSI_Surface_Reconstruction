# PSI Surface Reconstruction

MATLAB implementation of the phase-shifting interferometry (PSI) system previously split between LabVIEW acquisition and MATLAB processing.

The first version integrates:

- Thorlabs TPZ001 piezo controller through Kinesis .NET.
- Thorlabs DCC1545M camera through the DCx `uc480DotNet.dll` interface.
- Voltage scan and interferogram acquisition.
- Automatic selection of four interferograms separated by approximately 90 degrees.
- Four-step PSI phase reconstruction.
- Phase unwrapping, carrier removal, and phase-to-surface conversion.
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

The initial configuration reproduces the original acquisition convention where possible:

- Start voltage: 0 V
- Step: 0.1 V
- Images: 85
- Settling time: 0.5 s
- PSI frames: 4
- Phase-step target: 90 degrees
- Phase-step tolerance: 5 degrees
- Wavelength: 660 nm

These values are editable in the GUI or in `config/system_config.m`.

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
