%% afc_burn_pe_v0 measures burned afc gratings via direct scanning
% This script burns a frequency grating  and then reads out the comb via
% scanning

% designed to use the 80 MHZ and 30 MHZ agilent function generators and the
% pulses_class. 
% the 80 MHz agilent creates the comb. this output is
% combined with ch1 of the 30 MHz agilent, which provides the read pulse.
% ch2 of the 30 MHz sweeps the frequency during the burning sequence.
% if you can find a different way to sweep the frequency (i.e. the srs),
% then you can do multiple comb reads ala the afc_acc_pe_v0

% created 9/6/2015 by Jon Kindem. 
%% to do
% need one more version where I read out the comb created thru accumulated
% pe.
%% create objects
fgen1 = agilent33250a_class_new; % 80 MHz agilent
fgen2 = agilent33522a_class_new; % 30 MHz agilent (2 channels)
%sensl = senslrun;

%% open connections to the function generators
open(fgen1);
open(fgen2);

%% create figures 

% f1 = figure('Position',[5,250,600,750]);
% ha = axes;
% title('sensl read')
% sensl.axeshandle = ha;
% set(sensl.axeshandle,'NextPlot','replacechildren')
% 
% ylim(ha,[-1,30]);
% 
f2 = figure('Position',[5,250,600,400],'name','pulse input','menubar','none','visible','off');
hsp1 = subplot(3,1,1);
title('fgen1 out')
hsp2 = subplot(3,1,2);
title('fgen2.ch1 out')
hsp3 = subplot(3,1,3);
title('fgen2.ch1 out')

set(hsp1,'NextPlot','replacechildren')
set(hsp2,'NextPlot','replacechildren')
set(hsp3,'NextPlot','replacechildren')

yl = [-0.1,1.1];
ylim(hsp1,yl)
ylim(hsp2,yl)
ylim(hsp3,yl)

xl = [0 10];
xlim(hsp1,xl)
xlim(hsp2,xl)
xlim(hsp3,xl)
movegui(f2,'northwest')

%% function generator voltage settings 
fgen1.amp = 1;
fgen1.off = 0;

readamp = .5; % amplitude of read pulse

fgen2.ch1.amp = readamp;
fgen2.ch1.off = readamp/2;

fgen2.ch2.amp = 2; % scan amp
fgen2.ch2.off = 2.5; % scan off

%% function generator trigger settings
fgen1.trigsource = 'IMM';
fgen1.trigslope = 'NEG';
fgen1.trigoutslope = 'POS';

fgen2.ch1.trigsource = 'EXT';
fgen2.ch2.trigsource = 'EXT';
fgen2.ch1.trigslope = 'POS';
fgen2.ch2.trigslope = 'POS';

fgen2.ch2.trigdelay = 0;
%% sensl read settings.
% sensl.reads = 50; %number of reads
% sensl.runtime = '2000'; % length of each read in ms
% sensl.esr = '0055'; %5: rise/rise, 9: rise/fall, A: fall/fall, 6: fall/rise 0055
% sensl.histbins = (1:0.02:70)'; %bins for histogram. won't plot if empty.
% 
% I moved the filename/folder specification to the loop...
%% specifying experiment parameters

totaltime = 0.25; %total experiment time in seconds.

%%%% afc parameters
nwriteseq = 10; % number of write sequences.
writelength = 1000; % length of write sequence (us)

npulses = 7;
writepulse_widths = [50 repmat(50,1,npulses-2) 50]; % reminder: delays are specified in reference to the last pulse.
writepulse_heights = ones(1,npulses);
writepulse_delays = [10  repmat(100 ,1,npulses-1)]; %(us)

nreads = 5;

% note this is just for plotting. I currently ue the built in pulse
% function
readpulse_delays = 1;
readpulse_widths = writelength*nreads;
readpulse_heights = 1;
%readpulse_rep = 10;

waitdelays_exp = 1e-3;
waitdelays = (0); %delay between burning pulse and read pulse (units determined by waitdelays_exp)

totaldelays = waitdelays*waitdelays_exp + nwriteseq*writelength*fgen1.pulses.timeexp; % this is in seconds!


totalnscans = nwriteseq + ceil(waitdelays.*waitdelays_exp/(writelength*fgen1.pulses.timeexp)) + nreads;
% specifying shutter offset and width (if you're using fgen2.ch2 to drive
% the shutter)

shutter_offset = 0; % shouldn't really need to adjust this one...

% shutter_widths = 10; 
% shutter_delays = 2;
% shutter_heights = 1;

%% create pulses. 
% with this setup, you're not actually reloading the pulses during the
% experiment, just changing the relative timing... so you don't need to
% load on every loop. of course, you might want to do that at some point. 
% then i'd want to follow something more similar to the pe_scan format. but
% for now, I'll keep it simple.

% specifying pulse type and reference. 
fgen1.pulses.pulsetype = 'rectangular';
fgen1.pulses.pulseref = 'edge';

fgen2.ch1.pulses.pulsetype = 'rectangular';
fgen2.ch1.pulses.pulseref = 'edge'; % should be the same as fgen1...

%fgen2.ch2.pulses.pulsetype = 'rectangular';
%fgen2.ch2.pulses.pulseref = 'edge';

%defining parameters in terms of previous section.
fgen1.burstperiod = totaltime;
fgen1.ncyc = nwriteseq;
fgen2.ch1.ncyc = 1;
fgen2.ch2.ncyc = totalnscans(1);

% time steps used to create the pulses. adjust if things are too slow.
% by default, the timeexp is 1e-6. so all times are in us. 
fgen1.pulses.timestep = 0.1;
fgen2.ch1.pulses.timestep = 0.1;
fgen2.ch2.pulses.timestep = 0.05;

fgen1.pulses.totaltime = writelength;
fgen2.ch1.pulses.totaltime = readpulse_widths;
fgen2.ch2.pulses.totaltime = readpulse_widths;

fgen1.pulses.delays = writepulse_delays;
fgen1.pulses.widths = writepulse_widths; % can also use fgen2.pulses.setwidths([ 1 1 1]), but this also creates the pulses.
fgen1.pulses.heights = writepulse_heights;
fgen1.pulses.createpulses;

fgen2.ch1.pulses.delays = readpulse_delays;
fgen2.ch1.pulses.widths = readpulse_widths;
fgen2.ch1.pulses.heights = readpulse_heights; 
fgen2.ch1.pulses.createpulses;

%fgen2.send('SOURce1:FUNCtion PULSe');

% send pulse period before the width! (otherwise you'll get an error!)
% also, send the external trigger command before you turn burst on.
%fgen2.send(sprintf('SOURce1:FUNCtion:PULSe:PERiod %g',(readtime+1)*timeexp));
%fgen2.send(sprintf('SOURce1:FUNCtion:PULSe:WIDTh %g',readtime*timeexp));

%

fgen2.send(sprintf('SOURce2:FREQuency %8.5G',1/(writelength*fgen1.pulses.timeexp)))
rampsym = 0;  
fgen2.send('SOURce2:FUNCtion RAMP')
fgen2.send(sprintf('SOURce2:FUNCtion:RAMP:SYMMetry %g',rampsym))


%% send initial settings
fgen2.ch1.trigdelay = totaldelays(1);
fgen2.ch2.trigdelay = 0;
fgen2.ch2.pulses.createpulses;

% alternatively, if using the rear trigger output of fgen1 for the shutter
fgen1.trigdelay = fgen1.burstperiod/2 - totaldelays(1)-shutter_offset*fgen1.pulses.timeexp;

fgen1.output('off')
fgen2.ch1.output('off')
fgen2.ch2.output('off')
fgen1.sendall; % send all includes sendpulses, sendtrig, sendburst, and sendvolt
%pause(2)

% using the built in pulse function. if you'd rather use the arb waveform,
% use fgen2.ch2.sendall and comment out the rest
%fgen2.ch2.sendall
fgen2.send('SOURce1:FUNCtion PULSe');
fgen2.send(sprintf('SOURce1:FUNCtion:PULSe:PERiod %g',(readpulse_widths+1)*fgen2.ch2.pulses.timeexp));
fgen2.send(sprintf('SOURce1:FUNCtion:PULSe:WIDTh %g',readpulse_widths*fgen2.ch2.pulses.timeexp));
fgen2.ch1.sendtrig;
fgen2.ch1.sendburst;
fgen2.ch1.sendvolt;

%pause(2)
fgen2.ch2.sendtrig;
fgen2.ch2.sendburst;
fgen2.ch2.sendvolt;
%% plot 
set(f2,'visible','on')
fgen1.pulses.plot(hsp1)
fgen2.ch1.pulses.plot(hsp2)
%plotting a sawtooth
plot(hsp3,fgen1.pulses.tdata,fgen2.ch2.off + 0.5*fgen2.ch2.amp*sawtooth(2*pi*fgen1.pulses.tdata/writelength,rampsym))
%fgen2.ch2.pulses.plot(hsp3)
xlim(hsp1,[0 fgen1.pulses.totaltime])
xlim(hsp2,[0 fgen2.ch1.pulses.totaltime])
xlim(hsp3,[0 fgen1.pulses.totaltime])
ylim(hsp3,[0 5])

%% loop.
nsteps = length(waitdelays);
for it = 1:nsteps;
    %% create pulses for the current step.
    
    fgen2.ch1.trigdelay = totaldelays(it);
    fgen2.ch2.trigdelay = 0;
    % alternatively, if using the rear trigger output of fgen1 for the shutter
    fgen1.trigdelay = fgen1.burstperiod/2 - totaldelays(it)-shutter_offset*fgen1.pulses.timeexp;
    
    
    
    %% send pulses and settings to the function generators.
   % turn off outputs.
    %beep
    fgen1.output('off')
    fgen2.ch1.output('off')
    fgen2.ch2.output('off')
    % send all outputs 
    fgen1.sendtrig; % send all includes sendpulses, sendtrig, sendburst, and sendvolt
    fgen2.ch1.sendtrig;
    fgen2.ch2.sendtrig;
    fgen2.ch2.ncyc = totalnscans(it);
    fgen2.ch2.sendburst

    % wait
    pause(2)
    % turn on outputs.
    fgen1.output('on')
    fgen2.ch1.output('on')
    fgen2.ch2.output('on')
%     
    %% run sensl
%     % specify histogram bins for plotting.
%     sensl.histbins = ((shutter_delays(it)-1):0.025:(shutter_delays(it)+25))';
%     fprintf('sensl run %d of %d starting\n',it,nsteps)

%     %this doesn't actually need to be in the loop... just so all the
%     %file/folder naming is in one spot.
%     filenameprefix = 'test'; % will create a folder.
%     sensl.datadir = ['C:\Users\admin\Documents\faraonlab\20150622' '\' filenameprefix '\'];% directory to save files.

%     sensl.filename = sprintf('%s_d%g',filenameprefix,delays_mat(it,end));
%     sensl.filename = strrep(sensl.filename,'.','p');
%     
%     runandimport(sensl);
%     savesensl(sensl);
%     sensl.allreltimes = []; 
%     %need to clear otherwise will just keep replacing or else will just keep
%     %appending. alternatively, could create multiple senslrun objects?
%     pause(5)
%     fprintf('sensl run %d of %d finished \n',it,nsteps)
pause(10)
end

%% send email saying the run is done.
%sendmail('jkindem@caltech.edu','all done!');
%% close connections
%   close(fgen1)
%   close(fgen2)
