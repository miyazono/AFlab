% built from a few sources
%   http://www1.tek.com/forum/viewtopic.php?f=6&t=3217
%   Tektronix AWG5014 programmer manual from online saved in fgen_libraries
% 
% 
% Make sure to turn off the AWG5014 VXI-11 server (and probably GPIB) and
% enable LAN communication using port 4000 on the AWG5014 itself (its
% system menu in the program that runs the outputs)
% 
% If a session gets interrupted and the AWG refuses to connect to matlab, 
% turn LAN communication off and then on again (on the AWG5014 itself) and 
% then try reconnecting
% 
% If the marker vector doesn't load, check out and debug the
% create_waveform command - I had to do some sketchy shit to make it work.
%
% usage:
% 
% Awg_instance = Tektronix_AWG5014('169.254.178.97', 1064)
% Awg_instance.clear();
% Awg_instance.create_waveform('hole_amp', hole_amp_waveform, mark_start, mark_end);
% Awg_instance.set_channel_waveform(1,'hole_amp');
% Awg_instance.set_sampling_rate(sample_rate*1000);
% Awg_instance.set_repetition_rate(1/(total_time*1e-3));
% Awg_instance.start_output([1,2]);
% 
% ETM 20151105


classdef (ConstructOnLoad = true) Tektronix_AWG5014 < handle
    properties (SetAccess = private)
        awg_tcpip;
        buffer_size;
        
        channel_has_waveform;
        channel_output_on;
        sampling_rate_limits;
        
%         num
%         pulsess %stores start/stop of each pulse
%         pulseh %stores height of each pulse
%         lo = 0;
%         tt = 10;%total time
%         tdata %time vector with time steps (to make things easier to plot)
%         ydata %vector containing heights of arb wave
%         normydata
%         pulsetype = 'Rect';
%         ts = 0.1; %size of minimum step. 
%         timeexp = 1E-3;%use to get absolute time
%         amp = 1;
%         offset = 0;
%         freq %sampling frequency for arbitrary waveforms
%         ncyc = 1;
%         burstperiod = 1e-3; %time in seconds
%         trig = 10;
%         trigslope = 'POS';
%         datastring;
%         trigdata;
    end
    methods
        function obj = Tektronix_AWG5014(address, out_buffer_size)
            
            % check naively that address is IP-like (doesn't check <255)
            if regexp(address,'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$')
                instr_address = address;
            else
                instr_address  = '169.254.178.97';
                warning('provided address invalid, using 169.254.178.97');
            end
            
            if out_buffer_size <0
                obj.buffer_size = 1064;
            else
                obj.buffer_size = out_buffer_size;
            end
                        
            obj.awg_tcpip = tcpip(instr_address, 4000,'OutputBufferSize', obj.buffer_size);
              
            fopen(obj.awg_tcpip);     % Connect to instrument object, obj.
            
%             obj.clear();
            obj.channel_has_waveform = [0,0,0,0];
            obj.channel_output_on = [0,0,0,0];
            obj.sampling_rate_limits = [1e7, 10e9];
        end
        %% control
        function clear(obj)
            flushinput(obj.awg_tcpip);
            flushoutput(obj.awg_tcpip);
            fprintf(obj.awg_tcpip,'*rst;');
            fprintf(obj.awg_tcpip,'*cls;');
        end
    	function close(obj)
            warning('off','TekAWG5014:channelcheck')
            stop_output(obj,[1,2,3,4]);
            warning('on','TekAWG5014:channelcheck')
            fclose(obj.awg_tcpip);    % Disconnect all objects.
        end
        function start_output(obj,channels)
            for channel = 1:4
                % only turn on the passed in channels with waveforms loaded
                if ~isempty(find(channels==channel,1)) 
                    if obj.channel_has_waveform(channel)
                        fprintf(obj.awg_tcpip,['OUTP' num2str(channel) ' ON']);
                        obj.channel_output_on(channel) = 1;
                    else
                        warning('TekAWG5014:channelcheck',['channel ' num2str(channel) ...
                                 ' does not have a waveform loaded... dummy']);
                    end
                end
            end
            fprintf(obj.awg_tcpip, ':awgcontrol:run;');
        end
        function stop_output(obj,channels)
            fprintf(obj.awg_tcpip, ':awgcontrol:stop;');
            for channel = 1:4
                if ~isempty(find(channels==channel,1)) 
                    if obj.channel_output_on(channel)
                        fprintf(obj.awg_tcpip,['OUTP' num2str(channel) ' OFF']);
                        obj.channel_output_on(channel) = 0;
                    else
                        warning('TekAWG5014:channelcheck',['channel ' num2str(channel) ...
                                 ' was not on.  What kind of shit are you trying to pull?']);
                    end
                end
            end
        end
        % prevents execution of new commands until pending commands are executed
        function finish_current_command(obj)
            fprintf(obj.awg_tcpip, '*wai');
        end
        %% getters
        % lists both user defined and predefined waveforms
        function waveform_name_list = get_waveform_names(obj)
            fprintf(obj.awg_tcpip, 'wlist:size?');
            num_names = str2double(fscanf(obj.awg_tcpip));
            waveform_name_list = cell(num_names,1);
            for name_index = 1:num_names
                fprintf(obj.awg_tcpip, ['wlist:name? ' num2str(name_index-1)]);
                waveform_name_list{name_index} = fscanf(obj.awg_tcpip);
            end
        end
        function waveform_name = get_channel_waveform_name(obj, channel_num)
            fprintf(obj.awg_tcpip, [':source' num2str(channel_num) ':waveform?']);
            waveform_name = fscanf(obj.awg_tcpip);
        end
        function voltage_amplitude = get_channel_amplitude(obj, channel)
            fprintf(obj.awg_tcpip,[':source' num2str(channel) ':voltage?']);
            voltage_amplitude = fscanf(obj.awg_tcpip);
        end
        function sampling_rate_limits = get_sampling_rate_limits(obj)
            sampling_rate_limits = obj.sampling_rate_limits;
        end
        function num_steps = get_sequence_num_steps(obj)
            fprintf(obj.awg_tcpip,':SEQuence:length?');
            num_steps = str2double(fscanf(obj.awg_tcpip));
        end
        function total_points = get_total_loaded_points(obj)
            total_points = 0;
            names = get_waveform_names(obj);
            for waveform_index = 26:length(names) % first 25 are preloaded waveforms
                total_points = total_points + ...
                    get_waveform_length(obj,names{waveform_index});
            end
        end
        function length = get_waveform_length(obj, name)
            fprintf(obj.awg_tcpip,['WLISt:WAVeform:LENgth? ' name]);
            length = str2double(fscanf(obj.awg_tcpip));
        end
        function message = get_error_message(obj)
            fprintf(obj.awg_tcpip,':SYSTem:ERRor?');
            message = str2double(fscanf(obj.awg_tcpip));
        end

        %% setters
        % Send a waveform and markers to store in memory under the given
        % name.  Note: waveform_vector is scaled so that the largest value 
        % is either 1 or -1 (and a warning is thrown) while marker_vector 
        % must be either 0 or 1
        function create_waveform(obj, waveform_name, waveform_vector, marker_vector1, marker_vector2)
            if isempty(waveform_vector)
                error([waveform_name ' is empty']);
            end
            if max(waveform_vector)>1 || min(waveform_vector)<-1
                waveform_vector = waveform_vector / max(abs(waveform_vector));
                disp(['range is [' num2str(max(waveform_vector)) ',' num2str(min(waveform_vector)) ']'])
                warning('rescaling waveform_vector to be between -1 and 1')
            end
                
            if length(waveform_vector) ~= length(marker_vector1) || ...
                    length(waveform_vector) ~= length(marker_vector2)
                warning(['waveform and marker vectors must have equal ' ...
                         'length...  the markers are all set low until '...
                         'you get your shit together'],0);
                marker_vector1 = zeros(size(waveform_vector));
                marker_vector2 = marker_vector1;
            end
            
            waveform_length = length(waveform_vector);
            single_vector = single(waveform_vector);
            % reshape so each point is a byte column
            binary_waveform = reshape(typecast(single_vector,'uint8'),[4,waveform_length]);
            
            % encode marker 1 bits to bit 6
            m1 = bitshift(uint8(logical(marker_vector1)),6); %check dec2bin(m1(2),8)
            % encode marker 2 bits to bit 7
            m2 = bitshift(uint8(logical(marker_vector2)),7); %check dec2bin(m2(2),8)
            % merge markers
            marker_vector = m1 + m2; %check dec2bin(marker_vector(2),8)
            
            % add on the marker data
            binary_waveform_wmarker = vertcat(binary_waveform,marker_vector);
            
            % reshape to 4 wave bytes then 1 marker byte repeating
            binary_waveform_wmarker = reshape(binary_waveform_wmarker,1,5*waveform_length);
            
            bytes = num2str(length(binary_waveform_wmarker));
            header = ['#' num2str(length(bytes)) bytes];
            
            fprintf(obj.awg_tcpip,[':wlist:waveform:new "' ...
                waveform_name '",' num2str(waveform_length) ',REAL;']);
            send_long_command(obj,[':wlist:waveform:data "' ...
                waveform_name '",' header binary_waveform_wmarker ';']);
            
            % now set the marker data alone, because sometimes it fucks up
            % the end of the waveform when marker 2 is high at the end
            marker_bytes = num2str(length(marker_vector));
            marker_header = ['#' num2str(length(marker_bytes)) marker_bytes];
            send_long_command(obj,[':wlist:waveform:marker:data "' ...
                waveform_name '",' marker_header marker_vector+2^5 ';']);
            % OH MY GOD, THIS HAS TO BE THE WORST BUG I'VE EVER
            % ENCOUNTERED. THE ABOVE LINES SHOULD RESET THE MARKER TO WHAT
            % IT ALREADY IS BUT FOR SOME REASON THIS FIXES THE WAVEFORM?!?!
            % and don't ask me what the FUCK that 2^5 does exactly
            % but it fixes it somehow.
            
            % nice idea, but it takes way too long to run
%             if find(strcmp(get_waveform_names(obj),waveform_name))
%                 error(['well, shit... uploading ' waveform_name ' failed'])
%             end
        end
        function set_channel_waveform(obj, channel, waveform_name)
            fprintf(obj.awg_tcpip,[':source' num2str(channel) ':waveform "' waveform_name '";']);
            obj.channel_has_waveform(channel) = 1;
        end
        function set_channel_voltage_range(obj, channel, V_range)
            amplitude = range(V_range);
            offset = mean(V_range);
            if range(V_range) > 4.5
                warning(['voltage range on channel ' num2str(channel) ' is too high'])
            end
            if mean(V_range) < -2.25
                warning(['voltage offset on channel ' num2str(channel) ' is too low'])
            end
            if mean(V_range) > 2.25
                warning(['voltage offset on channel ' num2str(channel) ' is too high'])
            end
            fprintf(obj.awg_tcpip,[':source' num2str(channel) ':voltage ' num2str(amplitude)]);
            fprintf(obj.awg_tcpip,[':source' num2str(channel) ':voltage:offset ' num2str(offset) ]);
        end
        function set_channel_amp_volts(obj, channel, amplitude)
            fprintf(obj.awg_tcpip,[':source' num2str(channel) ':voltage ' num2str(amplitude)]);
        end
        function set_channel_offset_volts(obj, channel, offset)
            fprintf(obj.awg_tcpip,[':source' num2str(channel) ':voltage:offset ' num2str(offset) ]);
        end
        function set_marker_out_range(obj, channel, marker_num, marker_high, marker_low)
            fprintf(obj.awg_tcpip,[':source' num2str(channel) ':marker' num2str(marker_num) ':voltage:high ' num2str(marker_high) ]);
            fprintf(obj.awg_tcpip,[':source' num2str(channel) ':marker' num2str(marker_num) ':voltage:low ' num2str(marker_low) ]);
        end
        function set_repetition_rate(obj, rep_rate)
            fprintf(obj.awg_tcpip,[':awgcontrol:rrate ' num2str(rep_rate)]);
        end
        function set_sampling_rate(obj, samp_rate)
            if samp_rate < obj.sampling_rate_limits(1)
                warning(['sample rate too low.  setting to ' num2str(obj.sampling_rate_limits(1))])
                samp_rate = num2str(obj.sampling_rate_limits(1));
            else if samp_rate > obj.sampling_rate_limits(2)
                warning(['sample rate too high.  setting to ' num2str(obj.sampling_rate_limits(2))])
                samp_rate = num2str(obj.sampling_rate_limits(2));
                end
            end
            fprintf(obj.awg_tcpip,['source:frequency ' num2str(samp_rate) ]);
        end
        function set_sequence_mode_on(obj, bool)
            if bool
                fprintf(obj.awg_tcpip,'AWGControl:RMODe sequence');
            else
                fprintf(obj.awg_tcpip,'AWGControl:RMODe continuous');
            end
        end
        function set_channel_waveform_seq_step(obj, channel, step, waveform_name)
            fprintf(obj.awg_tcpip,['SEQuence:ELEMent' num2str(step) ':WAVeform' num2str(channel) ' "' waveform_name '";']);
            obj.channel_has_waveform(channel) = 1;
        end
        function set_channel_seq_step_loop_num(obj, step, loop_num)
            fprintf(obj.awg_tcpip,[':SEQuence:ELEMent' num2str(step) ':loop:count ' num2str(loop_num) ';']);
        end
        function set_sequence_num_steps(obj,numsteps)
            fprintf(obj.awg_tcpip,[':SEQuence:length ' num2str(numsteps) ]);
        end
        function set_sequence_step_goto(obj,gofrom_step,goto_step)
            fprintf(obj.awg_tcpip,[':SEQuence:ELEMent' num2str(gofrom_step) ':GOTO:STATe 1']);
            fprintf(obj.awg_tcpip,[':SEQuence:ELEMent' num2str(gofrom_step) ':GOTO:INDex ' num2str(goto_step) ]);
        end
        
        function delete_waveform_by_name(obj, name)
            % note, the name 'all' will delete all user waveforms
            fprintf(obj.awg_tcpip,[':wlist:waveform:delete' name]);
        end
        function clear_all_sequence_steps(obj)
            obj.set_sequence_num_steps(0);
            obj.channel_has_waveform = [0,0,0,0];
        end
        
        % to be used when sending commands over 1064 characters long
        function send_long_command(obj,command_string)
            bytes = length(command_string);
            if obj.buffer_size >= bytes
               % might have to make this fwrite for proper formatting?
               fprintf(obj.awg_tcpip,command_string);
            else
                % write buffer_size blocks till what's left is <buffer_size
                for i = 1:obj.buffer_size:bytes-obj.buffer_size
                    fwrite(obj.awg_tcpip,command_string(i:i+obj.buffer_size -1));
                end
                fwrite(obj.awg_tcpip,command_string(i+obj.buffer_size:end));
                obj.finish_current_command();
            end
        end
    end
end
