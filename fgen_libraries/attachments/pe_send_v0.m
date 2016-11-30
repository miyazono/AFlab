%% PE_SEND_V0 sends pulses for creating photon echoes. replacement for the GUI.
% designed to use the 80 MHZ and 30 MHZ agilent function generators and the
% pulses_class
% created 8/31/15 by Jon Kindem
%% create objects
fgen1 = agilent33250a_class_new; % 80 MHz agilent
fgen2 = agilent33522a_class_new; % 30 MHz agilent (2 channels)
%sensl = senslrun;

%% open connections to the function generators
open(fgen1);
%open(fgen2);

%% create pulse input figure
% f2 = figure('Position',[5,250,800,500],'name','pulse input','menubar','none','visible','off');
% movegui(f2,'northeast')
% 
% hsp1 = subplot(3,1,1);
% title('fgen1 out')
% hsp2 = subplot(3,1,2);
% title('fgen2.ch1 out')
% hsp3 = subplot(3,1,3);
% title('fgen2.ch1 out')
% 
% set(hsp1,'NextPlot','replacechildren')
% set(hsp2,'NextPlot','replacechildren')
% set(hsp3,'NextPlot','replacechildren')
% 
% yl = [-0.1,1.1];
% ylim(hsp1,yl)
% ylim(hsp2,yl)
% ylim(hsp3,yl)
% 
% xl = [0 20];
% xlim(hsp1,xl)
% xlim(hsp2,xl)
% xlim(hsp3,xl)
% 
% set(f2,'visible','on')

%% function generator voltage settings 
fgen1.amp = 1.5;%1.5V for two channels
fgen1.off = 0;

fgen2.ch1.amp = 1;
fgen2.ch1.off = 0;

fgen2.ch2.amp = 1;
fgen2.ch2.off = 0;

%% function generator trigger settings
fgen1.trigsource = 'IMM';
fgen1.trigslope = 'NEG';
fgen1.trigoutslope = 'POS';

fgen2.ch1.trigsource = 'EXT';
fgen2.ch2.trigsource = 'EXT';
fgen2.ch1.trigslope = 'POS';
fgen2.ch2.trigslope = 'POS';
fgen2.ch1.trigdelay = 0;
fgen2.ch2.trigdelay = 0;

%% pulse paramters
% specifying pulse type and reference. 
%fgen1.pulses.pulsetype = 'rectangular';
% fgen1.pulses.pulseref = 'edge';
fgen1.pulses.pulsetype = 'gaussian';
fgen1.pulses.pulseref = 'center';

fgen2.ch1.pulses.pulsetype = 'rectangular';
fgen2.ch1.pulses.pulseref = 'center'; % should be the same as fgen1...

fgen2.ch2.pulses.pulsetype = 'rectangular';
fgen2.ch2.pulses.pulseref = 'edge';

fgen1.ncyc = 1; % number of bursts 
fgen2.ch1.ncyc = 1;
fgen2.ch2.ncyc = 1;

fgen1.pulses.cutoff = 0.1;
fgen1.pulses.timestep = 0.01;
fgen2.ch1.pulses.timestep = 0.01;
fgen2.ch2.pulses.timestep = 0.05;
fgen1.pulses.totaltime = 10;
fgen2.ch1.pulses.totaltime = 10;
fgen2.ch2.pulses.totaltime = 10;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fgen1.burstperiod = 1e-3; % totaltime of each run in seconds

fgen1.pulses.delays = [2 1];
fgen1.pulses.widths = [.35 .45]; % can also use fgen2.pulses.setwidths([ 1 1 1]), but this also creates the pulses.
fgen1.pulses.heights = [1 1];
fgen1.pulses.createpulses;

% % scaling and offset for the fgen2 pulses.
% 
% delays2_scale = [1 1 ]; 
% delays2_offset = [0 0]; 
% 
% widths2_scale = 1*[1 1]; 
% widths2_offset = [0 0];
% 
% heights2_scale = [1 1]; 
% heights2_offset = [0 0];
% 
% % create matrix of parameters for fgen2. I'm assuming this scaling/offset
% % won't need to change during the loop, but that can be easily adjusted.
% fgen2.ch1.pulses.delays = delays2_scale.*fgen1.pulses.delays + delays2_offset;
% fgen2.ch1.pulses.widths = widths2_scale.*fgen1.pulses.widths + widths2_offset; 
% fgen2.ch1.pulses.heights = heights2_scale.*fgen1.pulses.heights + heights2_offset;
% fgen2.ch1.pulses.createpulses;
% 
% % if you'd rather set the fgen2 pulses independently, use this:
% % fgen2.ch1.pulses.delays = [1 1];
% % fgen2.ch1.pulses.widths = [1 1];
% fgen2.ch1.pulses.heights = [1 1];

% specifying shutter offset and width (if you're using fgen2.ch2 to drive the shutter)
shutter_offset = .15;
shutter_width = 10;

%I'm going to assume the shutter height/width won't be changed during the
%loop and set them here rather than in the loop.
fgen2.ch2.pulses.widths = shutter_width; 
fgen2.ch2.pulses.heights = 1;

switch fgen1.pulses.pulseref
    case 'center'
        %%% use this shutter def if using center to set pulse delay
        shutter_delay = sum(fgen1.pulses.delays) + 0.5*fgen1.pulses.widths(end) + shutter_offset;
    case 'edge'
        %%% use this shutter def if using edge to set pulse delay
        shutter_delay = sum(fgen1.pulses.delays) + sum(fgen1.pulses.widths) + shutter_offset;
        %disp('shutter ref is edge')
    otherwise
        error('pulse 1 ref not recognized! should be center or edge.')
end

fgen1.trigdelay = fgen1.burstperiod/2 - shutter_delay*fgen1.pulses.timeexp;

fgen2.ch2.pulses.delays = shutter_delay;
fgen2.ch2.pulses.createpulses;

%% plot pulses
% fgen1.pulses.plot(hsp1)
% fgen2.ch1.pulses.plot(hsp2)
% fgen2.ch2.pulses.plot(hsp3)
    
%% send pulses and settings to the function generators.
% turn off outputs.
fgen1.output('off')
%fgen2.ch1.output('off')
%fgen2.ch2.output('off')
% send all outputs 
pause(1)
fgen1.sendall; % send all includes sendpulses, sendtrig, sendburst, and sendvolt
%pause(2)
%fgen2.ch1.sendall;
%pause(2)
%fgen2.ch2.sendall;

% wait
pause(1)
% turn on outputs.
fgen1.output('on')
%fgen2.ch1.output('on')
%fgen2.ch2.output('on')

%% close connections
%   close(fgen1)
%   close(fgen2)

