%% afc_acc_pe_v0 is a revamped version of afc_v0 for measuring afc echoes.
% This script sends in multiple pairs of write pulses to create an
% accumulated AFC and then reads out the comb via photon echo

% designed to use the 80 MHZ and 30 MHZ agilent function generators and the
% pulses_class. the 80 MHz agilent creates the comb. this output is
% combined with ch1 of the 30 MHz agilent, which provides the read pulse.
% ch2 of the 30 MHz can be used as the shutter to allow for multiple reads
% of the comb in one experimental cycle.

% created 9/6/2015 by Jon Kindem. 
%%
% to do: finish all of it... make the loop function properly.

%% create objects
fgen1 = agilent33250a_class_new; % 80 MHz agilent
fgen2 = agilent33522a_class_new; % 30 MHz agilent (2 channels)
sensl = senslrun;

%% open connections to the function generators
open(fgen1);
open(fgen2);

%% create figures 

f1 = figure('name','sensl output','Position',[5,250,600,400]);
ha = axes;
%title('sensl read')
sensl.axeshandle = ha;
set(sensl.axeshandle,'NextPlot','replacechildren')
%movegui(f1,'northwest')

ylim(ha,[-1,30]);

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
fgen1.amp = 1.5; % should be 1.5 if you're powering two channels
fgen1.off = 0;

fgen2.ch1.amp = 1.5; % should be 1.5 if you're powering two channels.
fgen2.ch1.off = 0;

fgen2.ch2.amp = 4;
fgen2.ch2.off = 0;

%% function generator trigger settings
fgen1.trigsource = 'IMM';
fgen1.trigslope = 'NEG';
fgen1.trigoutslope = 'POS';

fgen2.ch1.trigsource = 'EXT';
fgen2.ch2.trigsource = 'EXT';
fgen2.ch1.trigslope = 'POS';
fgen2.ch2.trigslope = 'POS';
% fgen2.ch1.trigdelay = 0; % this is changed during the loop, so I might as
% well keep it commented out.
fgen2.ch2.trigdelay = 0;
%% sensl read settings.
sensl.reads = 100; %number of reads
sensl.runtime = '2000'; % length of each read in ms
sensl.esr = '0055'; %5: rise/rise, 9: rise/fall, A: fall/fall, 6: fall/rise 0055
sensl.histbins = (1:0.02:70)'; %bins for histogram. won't plot if empty.

% I moved the filename/folder specification to the loop...
%% specifying experiment parameters

totaltime = 0.100; %total experiment time in seconds.

%%%% afc parameters
nwritepairs = 50; % number of pulse pairs.
psep = 1; %separation between write pulses (us)
pdel = 50; %delay between pairs of pulses (us)

writepulse_delays = [2 psep]; % reminder: delays are specified in reference to the last pulse.
writepulse_widths = [.35 .35];
writepulse_heights = [1 1];

nreadpulses = 10;

readpulse_delays = 2;
readpulse_widths = .35;
readpulse_heights = 1;
readpulse_rep = 10;
%%%%%%%%%%%%%%%%%%
waitdelays_exp = 1e-3;
waitdelays = 1:1:10; %delay between burning pulse and read pulse (units determined by waitdelays_exp)
%%%%%%%%%%%%%%%%%%
writelength = psep + (nwritepairs-1)*pdel; % still in pulse units (us by default)
totaldelays = waitdelays*waitdelays_exp + writelength*fgen1.pulses.timeexp; % this is in seconds!

% specifying shutter offset. note! this will be different depending on
% whether you want to use rear trigger or fgen2. go negative to move the
% shutter forward (i.e. towards the echo)
shutter_offset =0.2;

%shutter pulse parameters (if you're using ch2 for the shutter, otherwise this does nothing)
shutter_widths = 5; 
shutter_delays = 1;
shutter_heights = 1;

%% create pulses. 
% with this setup, you're not actually reloading the pulses during the
% experiment, just changing the relative timing... so you don't need to
% load on every loop. of course, you might want to do that at some point. 
% then i'd want to follow something more similar to the pe_scan format. but
% for now, I'll keep it simple.

% specifying pulse type and reference. 
fgen1.pulses.pulsetype = 'gaussian';
fgen1.pulses.pulseref = 'center';

fgen2.ch1.pulses.pulsetype = 'gaussian';
fgen2.ch1.pulses.pulseref = 'center'; % should be the same as fgen1...

fgen2.ch2.pulses.pulsetype = 'rectangular';
fgen2.ch2.pulses.pulseref = 'edge';

%defining parameters in terms of previous section.
fgen1.burstperiod = totaltime;
fgen1.ncyc = nwritepairs;
fgen2.ch1.ncyc = nreadpulses;
fgen2.ch2.ncyc = nreadpulses;

% time steps used to create the pulses. adjust if things are too slow.
% by default, the timeexp is 1e-6. so all times are in us. 
fgen1.pulses.timestep = 0.01;
fgen2.ch1.pulses.timestep = 0.01;
fgen2.ch2.pulses.timestep = 0.01;

fgen1.pulses.totaltime = pdel;
fgen2.ch1.pulses.totaltime = readpulse_rep;
fgen2.ch2.pulses.totaltime = readpulse_rep;

fgen1.pulses.delays = writepulse_delays;
fgen1.pulses.widths = writepulse_widths; % can also use fgen2.pulses.setwidths([ 1 1 1]), but this also creates the pulses.
fgen1.pulses.heights = writepulse_heights;
fgen1.pulses.createpulses;

fgen2.ch1.pulses.delays = readpulse_delays;
fgen2.ch1.pulses.widths = readpulse_widths;
fgen2.ch1.pulses.heights =readpulse_heights; 
fgen2.ch1.pulses.createpulses;

fgen2.ch2.pulses.widths = shutter_widths;
fgen2.ch2.pulses.delays = shutter_delays;
fgen2.ch2.pulses.heights = shutter_delays;
fgen2.ch2.pulses.createpulses;
%% send all to function generator. during loop, will only need to update the trigger setting.
%apparently the 80 MHZ fgen delay doesn't have the us resolution I want, so
%I'm moving the shutter offset into the 30 MHZ channel...

% fgen2.ch1.trigdelay = totaldelays(1) + shutter_offset*fgen2.ch1.pulses.timeexp;
% fgen1.trigdelay = fgen1.burstperiod/2 - totaldelays(1);
% fgen2.ch2.trigdelay = 0;

fgen2.ch1.trigdelay = totaldelays(1);
fgen2.ch2.trigdelay = totaldelays(1) + shutter_offset*fgen2.ch2.pulses.timeexp;
fgen1.trigdelay = fgen1.burstperiod/2 - (totaldelays(1)+shutter_offset)*fgen1.pulses.timeexp;   

fgen1.output('off')
fgen2.ch1.output('off')
fgen2.ch2.output('off')
% send all outputs 
fgen1.sendall; % send all includes sendpulses, sendtrig, sendburst, and sendvolt
%pause(2)
fgen2.ch1.sendall;
%pause(2)
fgen2.ch2.sendall;

% wait
pause(2)
% turn on outputs.
fgen1.output('on')
fgen2.ch1.output('on')
fgen2.ch2.output('on')
%% plot 
set(f2,'visible','on');
fgen1.pulses.plot(hsp1)
fgen2.ch1.pulses.plot(hsp2)
fgen2.ch2.pulses.plot(hsp3)
xlim(hsp1,[0 fgen1.pulses.totaltime])
xlim(hsp2,[0 fgen2.ch1.pulses.totaltime])
xlim(hsp3,[0 fgen2.ch2.pulses.totaltime])

%% loop.
nsteps = length(waitdelays);
for it = 1:nsteps;
    %% create pulses for the current step.
    %this is to work around the lack of precision in the 80 MHZ trigger. 
%     fgen2.ch1.trigdelay = totaldelays(it) + shutter_offset*fgen2.ch1.pulses.timeexp;
%     fgen2.ch2.trigdelay = totaldelays(it);
%     fgen1.trigdelay = fgen1.burstperiod/2 - (totaldelays(it));
      
%   %alternatively, if you want to use ch2 for the shutter, this way makes
%   %more sense
    fgen2.ch1.trigdelay = totaldelays(it);
    fgen2.ch2.trigdelay = totaldelays(it) + shutter_offset*fgen2.ch2.pulses.timeexp;
    fgen1.trigdelay = fgen1.burstperiod/2 - (totaldelays(it)+shutter_offset)*fgen1.pulses.timeexp;   
    
    %% only need to send trigger during the loop.
    %turn off outputs.
    %beep
    fgen1.output('off')
    fgen2.ch1.output('off')
    fgen2.ch2.output('off')

    fgen1.sendtrig; 
    fgen2.ch1.sendtrig;
    fgen2.ch2.sendtrig;
    
    % wait
    pause(2)
    % turn on outputs.
    fgen1.output('on')
    fgen2.ch1.output('on')
    fgen2.ch2.output('on')
     
    %% run sensl
%     % specify histogram bins for plotting.
    %sensl.histbins = ((totaldelays(it)*1e6-1):0.025:(totaldelays(it)*1e6+10))';
    sensl.histbins = 0:0.025:10;
    fprintf('sensl run %d of %d starting\n',it,nsteps)

    %this doesn't actually need to be in the loop... just so all the
    %file/folder naming is in one spot.
    filenameprefix = 'surf2tz'; % will create a folder.
    sensl.datadir = ['C:\Users\admin\Documents\faraonlab\20151006' '\' filenameprefix ];% directory to save files.

    sensl.filename = sprintf('mdyso_m1p5_%s_d%g',filenameprefix,waitdelays(it));
    sensl.filename = strrep(sensl.filename,'.','p');
    
    runandimport(sensl);
    savesensl(sensl);
    sensl.allreltimes = []; 
    %need to clear otherwise will just keep replacing or else will just keep
    %appending. alternatively, could create multiple senslrun objects?
    %pause(5)
    fprintf('sensl run %d of %d finished \n',it,nsteps)
   pause(10)
end

close(f2)
%% send email saying the run is done.
sendmail('jkindem@caltech.edu','all done!');
%% close connections
%   close(fgen1)
%   close(fgen2)
