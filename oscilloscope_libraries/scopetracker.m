%% This program is an example/framework on connecting to the tektronix TDS 2024c
% and downloading waveforms

%% First, find the object and open the connection (copied from tmtool output)
   % Create a VISA-USB object.
interface_obj = instrfind('Type', 'visa-usb', 'RsrcName', 'USB0::0x0699::0x03A6::c019821::0::INSTR', 'Tag', '');

% Create the VISA-USB object if it does not exist
% otherwise use the object that was found.
if isempty(interface_obj)
    interface_obj = visa('AGILENT', 'USB0::0x0699::0x03A6::c019821::0::INSTR');
else
    fclose(interface_obj);
    interface_obj = interface_obj(1);
end

% Create a device object. 
osc = icdevice('tektronix_tds2024.mdd', interface_obj);

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
% % acquisition settings (i.e. averages, timebase, etc)
% acq_obj = get(osc,'Acquisition') 
% % turn on averaging with 16 per average
% set(acq_obj,'Mode','average')
% set(acq_obj,'NumberOfAverages',16)
% % set timebase to 10 us
% set(acq_obj,'Timebase',1.0E-5)

% channel specific settings
% chan_obj = get(osc,'Channel');
% turn channel 2 on, set voltage scale to 500 mV and center
%get(chan_obj(2),'State');
% set(chan_obj(2),'State','on')
% set(chan_obj(2),'Scale',.5)
% set(chan_obj(2),'Position',0)
%% reading waveform
% get group object
waveform_group = get(osc, 'Waveform');
waveform_group = waveform_group(1);

%read from scope repeatedly
nreads = 10;
waittime = .1; %seconds
tracelength = 2500;
chan2Y = zeros(nreads,tracelength);
chan2X = zeros(1,tracelength);
figure;
ha = axes;
set(ha,'NextPlot','replacechildren')
plot(ha,chan2X,chan2Y);
ylim([-1 1]);

%h = plot(chan2X,chan2Y,'YDataSource','chan2Y');
for readno = 1:nreads
    [chan2Y(readno,:), chan2X] = invoke(waveform_group, 'readwaveform', 'channel2');
	%refreshdata(h,'caller') % Evaluate y in the function workspace
	%drawnow; 
    plot(ha,chan2X,chan2Y);
    pause(waittime)
end



%% Save output to csvfile
filename = 'run1';
ext = '.csv';
%folder =  
delim = ' ';
%first write x values to first row
dlmwrite([filename ext],chan2X,'delimiter', delim)

dlmwrite([filename ext],chan2Y, '-append', ...
   'roffset', 1, 'delimiter',delim)

%then offset by one row and append y data

% Disconnect device object from hardware.
 disconnect(osc);
 delete(osc);