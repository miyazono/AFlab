function waveform = chirp_signal
% This function creates a RF chirp signal that sweeps about a 
% center frequency of 1.25 GHz.  The length of the sweep will 
% be the product of the period and the clock.   The in-phase 
% (I) and the quadrature (Q) components are defined using the 
% CHIRP function from MATLAB's Signal Processing Toolbox to 
% generate swept frequency cosine signals.

% Copyright 2009 - 2010 The MathWorks, Inc.

%% Set up parameters   
awgClock = 10e9;                            % AWG clock
centerFrequency = 1.25e9;          			% Center frequency
sweepPeriod = 4e-6;                			% Sweep period
startFrequency = -4.5e6;           			% Starting frequency
endFrequency = 4.5e6;              			% Ending frequency
waveformLength = sweepPeriod*awgClock;   		% Waveform length
sampleInterval = (0:waveformLength-1)/awgClock; % Sample interval
startIndex = 1;                                 % Start index

%% Create a sample waveform with I & Q
% In-phase component
inPhase = chirp(sampleInterval, startFrequency, sweepPeriod, ...
    endFrequency, 'linear');

% Quadature component
quadrature = chirp(sampleInterval,startFrequency,sweepPeriod,...
    endFrequency,'linear',-90);

% Combine the I & Q components
waveform = inPhase.*cos(2*pi*centerFrequency*sampleInterval) - ...
    quadrature.*sin(2*pi*centerFrequency*sampleInterval);