function surfaceNm = phaseToSurface(correctedPhase, wavelengthNm)
%PHASETOSURFACE Convert reflected optical phase to surface height in nm.

surfaceNm = wavelengthNm * correctedPhase / (4*pi);
end
