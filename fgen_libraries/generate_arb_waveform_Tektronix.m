% AWG M-Code for communicating with an instrument. 
%  
%   This is the machine generated representation of an instrument control 
%   session using a device object. The instrument control session comprises  
%   all the steps you are likely to take when communicating with your  
%   instrument. These steps are:
%       
%       1. Create a device object   
%       2. Connect to the instrument 
%       3. Configure properties 
%       4. Invoke functions 
%       5. Disconnect from the instrument 
%  
%   To run the instrument control session, type the name of the M-file,
%   awg, at the MATLAB command prompt.
% 
%   The M-file, AWG must be on your MATLAB PATH. For additional information
%   on setting your MATLAB PATH, type 'help addpath' at the MATLAB command
%   prompt.
%
%   Example:
%       awg;
%
%   See also ICDEVICE.
%

% Copyright 2009 - 2010 The MathWorks, Inc.
%   Creation time: 13-Jan-2009 10:53:43 

% Create a device object. 
deviceObj = icdevice('tektronix_awg5000_7000.mdd', 'TCPIP:169.254.178.97::4000');

% Connect device object to hardware.
connect(deviceObj);

% Execute device object function(s).
groupObj = get(deviceObj, 'Utility');
groupObj = groupObj(1);
invoke(groupObj, 'Reset');
groupObj = get(deviceObj, 'Arbwfm');
groupObj = groupObj(1);
invoke(groupObj, 'SendWaveformReal', 'chirp', chirp_signal);
groupObj = get(deviceObj, 'Channel');
groupObj = groupObj(1);
invoke(groupObj, 'putWaveform', 'ch1', 'chirp');

% Configure property value(s).
set(deviceObj.Control(1), 'SamplingRate', 50000000);

% Execute device object function(s).
groupObj = get(deviceObj, 'Channel');
groupObj = groupObj(1);
invoke(groupObj, 'putEnabled', 'ch1', 1);

% Disconnect device object from hardware.
disconnect(deviceObj);

% Delete object.
delete(deviceObj);
