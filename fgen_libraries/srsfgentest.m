% fgen = srsfgen;
% fgen.open;
% open(fgen)
%% how you send commands in general. Refer to the manual for syntax...
%fgen.send('FREQ 1e5');
fgen.send('AMPL 3.2VP');
fgen.send('OFFS 3.4');

%% example of sending rectangular pulses
fgen.pulsetype = 'rect';
% widths = [2 1 3]; %three pulses with widths 1, 2, and 3 (in us. can change by changing fgen.timexp)
% delays = [1 1 1]; %delays between pulses. for rectangular pulses, this is delay between end of pulse to start of next.
% heights = [1 1 1]; %heights (norm. to signal amplitude.) if empty, all are set to one.


fgen.timeexp = 1e-6;


% time_step = 1/(chop_freq*num_steps);   % in seconds




% widths  = [0,3];
% delays  = [0,12];
% heights = [0,1];



% widths = [0,time_step];
% heights = [0,1];
% delays_vec = (0:time_step:time_step*num_steps)' * [0,1];
% time_step = 1/(chop_freq*num_steps);   % in seconds
% 
% chop_freq = 20;                     % in Hz
% num_steps = 20;
% widths = [0,time_step];
% heights = [0,1];
% delays_vec = (0:time_step:time_step*num_steps)' * [0,1];
% 
% for delay_index = 1:num_steps
%     delays  = delays_vec(delay_index);
%     
%     fgen.varppe(widths,delays,heights); %creates pulses
%     fgen.sendpulses; %sends pulses to fgen.
%     pause(2);
% end


% for dly=100:100:50000
    

measurement_description = 'LN2_bulk_lifetime'; % description of measurement for external folder
LF_experiment_path = 'C:\Users\Faraon Lab\Documents\LightField\Experiments\IR-Setup_evan_automation.lfe';
% Setup_LightField_Environment();
% LF_instance = LightField_obj(true);
% LF_instance.load_experiment(LF_experiment_path);
date_n_time = clock;
        % saves in spectrometer subfolder YearMonthDay_lifetime
LF_savename_dir = ['C:\Users\Faraon Lab\Data\spectrometer\' ...
        num2str(date_n_time(1)) num2str(date_n_time(2),'%02.0f') num2str(date_n_time(3),'%02.0f') '_' measurement_description filesep];
LF_savename_prefix = 'lifetime_scan_';% ...
%        num2str(num_steps) 'steps_from' num2str(wavelength_sweep_min) 'to' num2str(wavelength_sweep_max) 'steps'];
mkdir([LF_savename_dir LF_savename_prefix]);
[LF_savename_prefix,LF_savename_dir,~] = uiputfile('.spe','Select file prefix', [LF_savename_dir LF_savename_prefix]);
LF_savename_prefix = LF_savename_prefix(1:strfind([LF_savename_prefix '.'],'.' )-1); % remove the extension that somtimes gets added
LF_instance.set_savedir(LF_savename_dir);
LF_instance.set_incrementname(false);
LF_instance.set_add_date_to_name(false);





figure()

%% take data
% initiate laser pulsing and data recording
fgen.ts = 100;
laser_on=20000; % this is in us
integration_time=50000;
% dlys = 500:500:22000;
dlys = 500:10000:20500;
raw_data = zeros(1024, length(dlys));
cleaned_data = zeros(size(raw_data));
peak_size_wet = zeros(length(dlys),1);
peak_size_raw = zeros(length(dlys),1);
peak_size_clean = zeros(length(dlys),1);
edge_noise_buffer = 1;
bandpass_width = 10;


for delay_index = 1:length(dlys)
    
    widths  = [0,laser_on];
    delays  = [0,integration_time];
    heights = [0,1];

    fgen.tt = laser_on+dlys(delay_index)+integration_time; % add 1ms spacer between end of exposure and laser turnon
    fgen.varppe(widths,delays,heights); %creates pulses
    fgen.tt = laser_on+dlys(delay_index)+integration_time;
%     send(fgen,'AMPL 5VP') 
    fgen.sendpulses; %sends pulses to fgen.

    
    LF_instance.set_savename([LF_savename_prefix '_' num2str(dlys(delay_index)) 'us_delay']);
    counts = LF_instance.acquire();
    raw_data(:,delay_index) = sum(counts,3);
    
%   process data
    wet_data = raw_data(:,delay_index) ;%%%- dark_data';
    wet_data = wet_data - min(wet_data);
    [~, max_index] = max(wet_data);
    left_bp = max(max_index - bandpass_width*2,0);
    right_bp = min(max_index + bandpass_width*2,length(wet_data));
    cleaned_data(:,delay_index) = wet_data/mean([ wet_data(edge_noise_buffer:left_bp); wet_data(right_bp:end-edge_noise_buffer+1)]);
    
    left_peak_bp = floor(max_index - (bandpass_width-1)/2);
    right_peak_bp = ceil(max_index + (bandpass_width-1)/2);
    
    
    peak_size_raw(delay_index) = sum(raw_data(left_peak_bp:right_peak_bp,delay_index));
    subplot(2,2,1)
    plot(dlys, peak_size_raw)
    
    peak_size_wet(delay_index) = sum(wet_data(left_peak_bp:right_peak_bp));
    subplot(2,2,2)
    plot(dlys, peak_size_wet)
        
    left_peak_bp = floor(max_index - (bandpass_width-3)/2);
    right_peak_bp = ceil(max_index + (bandpass_width-3)/2);
    peak_size_clean(delay_index) = sum(wet_data(left_peak_bp:right_peak_bp));
    subplot(2,2,3)
    plot(dlys, peak_size_clean)
    
    subplot(2,2,4)
    plot(dlys, max(raw_data))
    
end

% figure()
% plot(dlys,raw_data)




% pause(4)
% end

%% example of sending gaussian pulses
% fgen.pulsetype = 'gauss';
% widths = [1 2 3]; %three pulses with widths 1, 2, and 3 (in us. can change by changing fgen.timexp)
% delays = [1 2 1]; %delays between pulses. for gaussian pulses, this is delay between center of each pulse
%%
%figure;
%plotpulses(fgen)
% fgen.close
 %close(fgen)

%% alternative syntax
% fgen = srsfgen;
% open(fgen)
% send(fgen,'AMPL0.6VP') 
% close(fgen)