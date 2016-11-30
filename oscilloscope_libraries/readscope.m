%% This program is an example/framework on connecting to the tektronix TDS 2014B
% and downloading waveforms
% based on Jon's script to run the TDS 2024C

%% First, find the object and open the connection (copied from tmtool output)
   % Create a VISA-USB object.
interface_obj = instrfind('Type', 'visa-usb', 'RsrcName', 'USB0::0x0699::0x0368::C034313::0::INSTR', 'Tag', '');

% Create the VISA-USB object if it does not exist
% otherwise use the object that was found.
if isempty(interface_obj)
    interface_obj = visa('AGILENT', 'USB0::0x0699::0x0368::C034313::0::INSTR');
else
    fclose(interface_obj);
    interface_obj = interface_obj(1);
end

% Create a device object. 
osc = icdevice('tektronix_tds2014.mdd', interface_obj);

% Connect device object to hardware.
connect(osc);
%to get list of settings that can be configured
%set(osc)
%to get the current configuration of the oscilloscope
%get(osc)
%% configuring trigger (as example of setting up scope)
% trigger_group = get(osc, 'Trigger');
% %use get command to read property
% get(trigger_group, 'Slope' );
% %use set command to set.
% set(trigger_group, 'Slope', 'falling');
% %can get list of other properties using
% get(trigger_group)
%% other things
% acquisition settings (i.e. averages, timebase, etc)
acq_obj = get(osc,'Acquisition') 
% turn on averaging with 16 per average
set(acq_obj,'Mode','average')
set(acq_obj,'NumberOfAverages',16)
% set timebase to 10 us
set(acq_obj,'Timebase',1.0E-5)

% channel specific settings
% chan_obj = get(osc_obj,'Channel')
% turn channel 2 on, set voltage scale to 500 mV and center
% set(chan_obj(2),'State','on')
% set(chan_obj(2),'Scale',.5)
% set(chan_obj(2),'Position',0)
%% reading waveform
% get group object
waveform_group = get(osc, 'Waveform')
waveform_group = waveform_group(1);
[Y, X] = invoke(waveform_group, 'readwaveform', 'channel2');



figure;
plot(X,Y);
% xlim([(p2s/2-1*p1l)*1e-6 (p2s/2+4*p1l)*1e-6]);
% ylim([min(Y) 1.2*max(Y)]);

% Disconnect device object from hardware.
disconnect(osc);
% delete(osc);