% Sequence_loader v7
% Object that interfaces with the Tektronix_AWG5014 object to more cleanly
% deliver and keep track of various pulse steps in a sequence to eliminate
% unnecessary loading of long steps (breaks down and loops flat steps)
% 
% Constructor takes an active Tektronix_AWG5014 object and each run_***
% takes a fully populated <sequence> struct.  A <sequence> struct's 
% parameters vary by function, and are outlined in each function
% 
%
% Within this object, the internal <step> struct is presumed to contain
%     name - step name, with a specific format including all relevent info
%     amp_wave - amplitude vector for one channel
%     freq_wave - frequency vector for second channel
%     output_wave - amplitude vector for third channel
%     scan_marker - logical marker vector, 1 for 2nd half of scan
%     input_marker - logical marker vector, 1 when the amp_wave is >0
%     sync_marker - logical marker vector, 1 to trigger counting board
%     output_marker - logical marker vector, 1 for the entire "listen" step
%     MEMS_marker - logical marker, two states to block or allow output
%     num_loops - number of times this sequence segment is to be looped
%       this value is not included until append_to_sequence and setting as 
%       current_steps to prevent unintended looping
%   The step contains both logical and frequency because all steps of the
%   same index are required by the Awg to have the same length.
% 
% output chanels are as follows:
%   amplitude waveform - voltage to the AOM 
%       - marker 1: input_marker - high when input (AOM) is >0 (for RF switch)
%       - marker 2: sync_marker - triggers timing card (timeharp) for scan or read
%   freq waveform - voltage to the laser piezo
%       - marker 1: scan_marker - triggers on the middle of the scan range
%       - marker 2: MEMS_marker - a pulse at beginng and end of read or scan pulse
%   output waveform
%       - marker 1: output_marker - high when output is 1
%       - marker 2: 1-input_marker - high when input is 0
%
% v2 - 3 channel output support
% v3 - now 100% arse free (shortened seq step names)
%    - also supports echos and accumulated AFCs
% v4 - also supports stepNburn AFCs
% v5 - cleaned up marker channels to separate MEMS and sync markers
% v6 - includes trench burning (with scan & PL readout)
% v7 - changed all MEMS marker code from toggle to high-on, low-off mode
% 
% ETM,IC 20160203 

classdef (ConstructOnLoad = true) Sequence_loader < handle
    properties (SetAccess = private)
        Awg_instance;
        
        % loaded_steps contains all loaded 'step' structs, uniquely named,
        % which includes the step type (i.e. burn, wait) and relevant params.
        loaded_steps;
        total_loaded_points;
        freq_channel_num;
        input_channel_num;
        output_channel_num;
        output_channel_on;

        sample_rate = 50000; %200000; % 1e6; %  samples per s
        trigger_time = 1/10;  % in ms (MEMS switch intermittently misses shorter)
        max_flat_time;
        verbose;
        current_steps;
        current_sequence;
        
        MEMS_block_output = 0;
        MEMS_pass_output = 1;
        output_block = -1;
        output_pass = 1;
        
    end
    methods
        function obj = Sequence_loader(Awg_instance)
            Awg_instance.clear();
            obj.Awg_instance = Awg_instance;
            obj.loaded_steps = {};
            obj.total_loaded_points = 0;
            obj.Awg_instance.set_sequence_mode_on(true);
            
            obj.output_channel_num = 2;
            obj.input_channel_num = 3;
            obj.freq_channel_num = 4;
            obj.max_flat_time = 10; % in ms
            obj.verbose = true;

            % set the MEMS marker amplitude
            % set_marker_out_range(obj, channel, marker_num, marker_high, marker_low)
            obj.Awg_instance.set_marker_out_range(obj.freq_channel_num, 2, 2, 0)
        end

        function sequence = get_current_sequence(obj)
            sequence = obj.current_sequence;
        end
        function clean_for_new_sequence(obj)
            if obj.total_loaded_points > 129.6e6 - 50e6  % AWG only holds 129.6e6 total points
                if obj.verbose
                    disp(['*** Total number of stored waveform points ('...
                          num2str(obj.total_loaded_points) ...
                          ') is too large; clearing waveforms ***'])
                end
                obj.Awg_instance.delete_waveform_by_name('all')

                obj.loaded_steps = {};
                obj.total_loaded_points = 0;
            end
            
            obj.Awg_instance.clear_all_sequence_steps();
            obj.Awg_instance.set_sequence_mode_on(true);
            obj.Awg_instance.set_sampling_rate(obj.sample_rate*1000);
        end

        function run_hole_burn(obj, sequence)
            % A _sequence_ struct is presumed to contain:
            %     total_time - total time of the run (next 3 values + end buffer)
            %     burn_time - time duration of hole burn
            %     wait_time - time duration of wait between burn end and midscan
            %     scan_time - time for linear region of scan
            %     input_rise_time - rise time for AOM signal (reduce ringing)
            %     freq_rise_time - rise time for laser piezo (reduce ringing)
            %     burn_amplitude - amplitude (to AOM) of burn pulse between 0,1
            %     scan_amplitude - amplitude (to AOM) of scan pulse between 0,1
            %     hole_freq_offset - piezo offset during hole burn
            %     wait_freq_offset - piezo offset during wait time
            %     scan_freq_range - 1x2 vector with min and max of piezo scan range
        
            obj.clean_for_new_sequence();
            
            obj.output_channel_on = 1; % turn on output channel loadings for this
            
            intermission_time = sequence.total_time - sequence.burn_time...
                                - sequence.wait_time - sequence.scan_time;

            if sequence.input_rise_time > sequence.wait_time || ... 
                    sequence.freq_rise_time > sequence.wait_time
                error('increase wait time or decrease rise time')
            end
            if 2*sequence.input_rise_time > intermission_time || ...
                    2*sequence.freq_rise_time > intermission_time
                error('increase total time or decrease rise time')
            end
            
            %% burn
            burn_steps = obj.frac_n_make_burn_step(sequence.freq_rise_time,...
                            sequence.input_rise_time,sequence.burn_time,...
                            sequence.burn_amplitude,sequence.hole_freq_offset,...
                            sequence.wait_freq_offset,obj.output_block,obj.MEMS_block_output);
            obj.append_to_sequence(burn_steps);
            
            %% wait
            wait_steps = obj.frac_n_make_wait_step(sequence.wait_time - ...
                    2*sequence.freq_rise_time, sequence.wait_freq_offset, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(wait_steps);
            
            %% scan
            scan_step = obj.make_scan_n_triggersync_step(sequence.freq_rise_time,...
                            sequence.input_rise_time, sequence.scan_time,...
                            sequence.scan_freq_range, sequence.scan_amplitude,...
                            sequence.wait_freq_offset);
            obj.append_to_sequence(scan_step);
            
            %% wait2
            wait_steps2 = obj.frac_n_make_wait_step(intermission_time - ...
                    2*sequence.freq_rise_time, sequence.wait_freq_offset, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(wait_steps2);
            
            
            %% run stuff
            obj.current_steps = [burn_steps, wait_steps, scan_step, wait_steps2];
            obj.current_sequence = sequence;
            obj.Awg_instance.finish_current_command();
            obj.close_sequence_loop();
            obj.Awg_instance.start_output([obj.input_channel_num,obj.freq_channel_num]);
            if obj.output_channel_on
                obj.Awg_instance.start_output(obj.output_channel_num);
            end
        end
        function run_trench_burn_scan(obj, sequence)
            % A _sequence_ struct is presumed to contain:
            %     total_time - total time of the run (next 3 values + end buffer)
            %     burn_time - time duration of hole burn
            %     wait_time - time duration of wait between burn end and midscan
            %     scan_time - time for linear region of scan
            %     input_rise_time - rise time for AOM signal (reduce ringing)
            %     freq_rise_time - rise time for laser piezo (reduce ringing)
            %     burn_amplitude - amplitude (to AOM) of burn pulse between 0,1
            %     scan_amplitude - amplitude (to AOM) of scan pulse between 0,1
            %     hole_freq_offset - piezo offset during hole burn
            %     wait_freq_offset - piezo offset during wait time
            %     scan_freq_range - 1x2 vector with min and max of piezo scan range
        
            obj.clean_for_new_sequence();
            
            obj.output_channel_on = 1; % turn on output channel loadings for this
            
            intermission_time = sequence.total_time - sequence.burn_time...
                                - sequence.wait_time - sequence.scan_time;

            if sequence.wait_time < 4*obj.trigger_time 
                error('Wait time before scan pulse is too short for MEMS switch trigger pulse')
            end
            if sequence.input_rise_time > sequence.wait_time
                error('increase wait time or decrease rise time')
            end
            if sequence.input_rise_time > intermission_time
                error('increase total time or decrease rise time')
            end
            
            %% burn
            burn_steps = obj.frac_n_make_burn_trench_step(sequence.freq_modulation_period, ...
                                sequence.input_rise_time,sequence.burn_time,...
                                sequence.burn_amplitude,sequence.trench_fraction);
            obj.append_to_sequence(burn_steps);
            
            %% wait (keep MEMS off for some additional time to block burn pulse)
            wait_steps_MEMS = obj.frac_n_make_wait_step(4*obj.trigger_time, 0, obj.output_block, obj.MEMS_block_output);
            obj.append_to_sequence(wait_steps_MEMS);
            
            wait_steps = obj.frac_n_make_wait_step(sequence.wait_time - 4*obj.trigger_time - ...
                    sequence.freq_rise_time, 0, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(wait_steps);
            
            %% scan
            scan_step = obj.make_scan_n_triggersync_step(sequence.freq_rise_time, sequence.input_rise_time, ...
                            sequence.scan_time, sequence.scan_freq_range, sequence.scan_amplitude,0);
            obj.append_to_sequence(scan_step);
            
            %% wait2
            wait_steps2 = obj.frac_n_make_wait_step(intermission_time - 4*obj.trigger_time - ...
                    sequence.freq_rise_time,0,obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(wait_steps2);
            obj.append_to_sequence(wait_steps_MEMS);
            
            %% run stuff
            obj.current_steps = [burn_steps, wait_steps_MEMS, wait_steps, scan_step, wait_steps2, wait_steps_MEMS];
            obj.current_sequence = sequence;
            obj.Awg_instance.finish_current_command();
            obj.close_sequence_loop();
            obj.Awg_instance.start_output([obj.input_channel_num,obj.freq_channel_num]);
            if obj.output_channel_on
                obj.Awg_instance.start_output(obj.output_channel_num);
            end
        end
        function run_trench_burn(obj, sequence)
            % A _sequence_ struct is presumed to contain:
            %     total_time - total time of the run (next 3 values + end buffer)
            %     burn_time - time duration of hole burn
            %     wait_time - time duration of wait between burn end and midscan
            %     scan_time - time for linear region of scan
            %     input_rise_time - rise time for AOM signal (reduce ringing)
            %     freq_rise_time - rise time for laser piezo (reduce ringing)
            %     burn_amplitude - amplitude (to AOM) of burn pulse between 0,1
            %     scan_amplitude - amplitude (to AOM) of scan pulse between 0,1
            %     hole_freq_offset - piezo offset during hole burn
            %     wait_freq_offset - piezo offset during wait time
            %     scan_freq_range - 1x2 vector with min and max of piezo scan range
        
            obj.clean_for_new_sequence();
            
            obj.output_channel_on = 1; % turn on output channel loadings for this
            
            intermission_time = sequence.total_time - sequence.burn_time...
                                - sequence.wait_time - sequence.read_time;
            
            if sequence.wait_time < 4*obj.trigger_time 
                error('Wait time before scan pulse is too short for MEMS switch trigger pulse')
            end
            
            if sequence.input_rise_time > sequence.wait_time
                error('increase wait time or decrease rise time')
            end
            if sequence.input_rise_time > intermission_time
                error('increase total time or decrease rise time')
            end
          
            
            %% burn
            if sequence.burn_time <= 0
                burn_steps = [];
            else
                burn_steps = obj.frac_n_make_burn_trench_step(sequence.freq_modulation_period, ...
                                sequence.input_rise_time,sequence.burn_time,...
                                sequence.burn_amplitude,sequence.trench_fraction);
                obj.append_to_sequence(burn_steps);
            end
            %% wait (keep MEMS off for some additional time to block burn pulse)
            wait_steps_MEMS = obj.frac_n_make_wait_step(4*obj.trigger_time, 0, obj.output_block, obj.MEMS_block_output);
            obj.append_to_sequence(wait_steps_MEMS);
            
            wait_steps = obj.frac_n_make_wait_step(sequence.wait_time - 4*obj.trigger_time, 0, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(wait_steps);
            %% readout
            if sequence.block_readout_step == 0
                readout_output = obj.output_pass;
            else
                readout_output = obj.output_block;
            end
            
            readout_step = make_readout_step(obj, sequence.read_amplitude,...
                            sequence.read_time, 0, 0,readout_output, 1);        
            obj.append_to_sequence(readout_step);
            
            %% wait2 (turn MEMS off for some additional time to block burn pulse)
            wait_steps2 = obj.frac_n_make_wait_step(intermission_time -4*obj.trigger_time, 0, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(wait_steps2);
      
            obj.append_to_sequence(wait_steps_MEMS);
            %% run stuff
            obj.current_steps = [burn_steps, wait_steps_MEMS, wait_steps, readout_step, wait_steps2, wait_steps_MEMS];
            obj.current_sequence = sequence;
            obj.Awg_instance.finish_current_command();
            obj.close_sequence_loop();
            obj.Awg_instance.start_output([obj.input_channel_num,obj.freq_channel_num]);
            if obj.output_channel_on
                obj.Awg_instance.start_output(obj.output_channel_num);
            end
        end
        function run_stepNburn_afc_scan(obj, sequence)
            % burns and then scans an afc at 0 frequency detuning of the laser
            % A _sequence_ struct is presumed to contain:
            %     burn_amplitude - heights of pulses
            %     burn_times - width of pulses in ms
            %     wait_time - wait time between pulses in ms
            %     teeth_range - [min,max] of linear region of scan
            %     num_teeth - number of teeth to be burned in the comb
            %     num_burn_loops - number of times to sweep over the full comb
            %     input_rise_time - rise time for input signal (reduce ringing)
            %     out_rise_time - rise time for output signal (reduce ringing)
            %     freq_rise_time - rise time for frequency signal (reduce ringing)
            %     wait_freq_offset - piezo offset during wait time
            %     hole_freq_offset - piezo offset during burn time
            %     scan_amplitude - amplitude (to AOM) of scan pulse between 0,1
            %     scan_freq_range - 1x2 vector with min and max of piezo scan range

            obj.clean_for_new_sequence();
            obj.output_channel_on = 0;

            if sequence.wait_times(2) < obj.trigger_time
                error('Wait time before scan pulse is too short for MEMS switch trigger pulse')
            end
            if sequence.wait_times(3) < obj.trigger_time
                error('Wait time after scan pulse is too short for MEMS switch trigger pulse')
            end

            % if 2*sequence.input_rise_time > sequence.wait_times(1)
            %     error('increase wait between burn pulses or decrease rise time')
            % end
            % if 2*sequence.input_rise_time > sequence.wait_times(3) || ...
            %         2*sequence.freq_rise_time > sequence.wait_times(3)
            %     error('increase prescan wait time or decrease rise time')
            % end
            % if 2*sequence.input_rise_time > sequence.wait_times(4) || ...
            %         2*sequence.freq_rise_time > sequence.wait_times(4)
            %     error('increase postscan wait time or decrease rise time')
            % end
            
            %% burn
            stepNburn_step = obj.make_stepNburn_step_loop(sequence.burn_amplitude,...
                            sequence.burn_time, sequence.wait_times(1), sequence.num_teeth,...
                            sequence.num_burn_loops, sequence.burn_freq_rise_time,...
                            sequence.input_rise_time, sequence.hole_freq_offset,...
                            sequence.teeth_range, sequence.wait_freq_offset);
            obj.append_to_sequence(stepNburn_step);
            
            %% wait
            prescan_wait_steps = obj.frac_n_make_wait_step(sequence.wait_times(2), ...
                                        sequence.wait_freq_offset, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(prescan_wait_steps);
            
            %% scan
            scan_step = obj.make_scan_n_triggersync_step(sequence.freq_rise_time,...
                            sequence.input_rise_time, sequence.scan_time,...
                            sequence.scan_freq_range, sequence.scan_amplitude,...
                            sequence.wait_freq_offset);
            obj.append_to_sequence(scan_step);
            
            %% wait
            postscan_wait_steps = obj.frac_n_make_wait_step(sequence.wait_times(3), ...
                                        sequence.wait_freq_offset, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(postscan_wait_steps);
            

            %% run stuff
            obj.current_steps = [stepNburn_step, prescan_wait_steps, ...
                                 scan_step, postscan_wait_steps];
            obj.current_sequence = sequence;
            obj.close_sequence_loop();
            obj.Awg_instance.start_output([obj.input_channel_num,obj.freq_channel_num]);
            if obj.output_channel_on
                obj.Awg_instance.start_output(obj.output_channel_num)
            end
        end
        function run_stepNburn_afc_echo(obj, sequence)
            % burns and then scans an afc at 0 frequency detuning of the laser
            % A _sequence_ struct is presumed to contain:
            %     burn_amplitude - heights of pulses
            %     burn_times - width of pulses in ms
            %     wait_time - wait time between pulses in ms
            %     teeth_range - [min,max] of linear region of scan
            %     num_teeth - number of teeth to be burned in the comb
            %     num_burn_loops - number of times to sweep over the full comb
            %     input_rise_time - rise time for input signal (reduce ringing)
            %     out_rise_time - rise time for output signal (reduce ringing)
            %     freq_rise_time - rise time for frequency signal (reduce ringing)
            %     wait_freq_offset - piezo offset during wait time
            %     hole_freq_offset - piezo offset during burn time
            
            %     read_amplitude - amplitude (to AOM) of read pulse between 0,1
            %     read_time - time duration of the read pulse
            %     num_read_loops - number of reads per AFC
            
            obj.clean_for_new_sequence();
            obj.output_channel_on = 0;

            if sequence.wait_times(2) < obj.trigger_time
                error('Wait time before scan pulse is too short for MEMS switch trigger pulse')
            end
            if sequence.wait_times(4) < obj.trigger_time
                error('Wait time after scan pulse is too short for MEMS switch trigger pulse')
            end
            
            %% burn
            stepNburn_step = obj.make_stepNburn_step_loop(sequence.burn_amplitude,...
                            sequence.burn_time, sequence.wait_times(1), sequence.num_teeth,...
                            sequence.num_burn_loops, sequence.burn_freq_rise_time,...
                            sequence.input_rise_time, sequence.hole_freq_offset,...
                            sequence.teeth_range, sequence.wait_freq_offset);
            obj.append_to_sequence(stepNburn_step);
            
            %% wait
            
            prescan_wait_steps = obj.frac_n_make_wait_step(sequence.wait_times(2), ...
                                        sequence.wait_freq_offset, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(prescan_wait_steps);
            
            %% read
            if sequence.block_readout_step == 0
                readout_output = obj.output_pass;
            else
                readout_output = obj.output_block;
            end
            
            readout_step = obj.make_readout_step(sequence.read_amplitude,...
                            sequence.read_time, sequence.wait_times(3), ...
                            sequence.hole_freq_offset, readout_output, sequence.num_read_loops);
            obj.append_to_sequence(readout_step);
            
            %% wait
            postscan_wait_steps = obj.frac_n_make_wait_step(sequence.wait_times(4), sequence.wait_freq_offset, obj.output_pass, obj.MEMS_pass_output); % 1 for output
            obj.append_to_sequence(postscan_wait_steps);

            
            %% run stuff
            obj.current_steps = [stepNburn_step, prescan_wait_steps, ...
                readout_step, postscan_wait_steps];
            obj.current_sequence = sequence;
            obj.close_sequence_loop();
            obj.Awg_instance.start_output([obj.input_channel_num,obj.freq_channel_num]);
            if obj.output_channel_on
                obj.Awg_instance.start_output(obj.output_channel_num)
            end

            % set MEMS switch output
            obj.Awg_instance.set_marker_out_range(4, 2, 2.5, 0);
        end
        function run_accumulated_afc(obj, sequence)
            % burns and then scans an afc at 0 frequency detuning of the laser
            % A _sequence_ struct is presumed to contain:
            %     burn_amplitudes - height of [first,second] pulses
            %     burn_times - width of [first,second] pulses in ms
            %     wait_times - wait time after [pulse1,pulse2,before scan,after scan] in ms
            %     scan_time - time for linear region of scan
            %     num_burn_loops - number of times to send in burn pairs
            %     input_rise_time - rise time for input signal (reduce ringing)
            %     out_rise_time - rise time for output signal (reduce ringing)
            %     freq_rise_time - rise time for frequency signal (reduce ringing)
            %     wait_freq_offset - piezo offset during wait time
            %     hole_freq_offset - piezo offset during burn time
            %     scan_amplitude - amplitude (to AOM) of scan pulse between 0,1
            %     scan_freq_range - 1x2 vector with min and max of piezo scan range

                        
            obj.clean_for_new_sequence();
            obj.output_channel_on = 0; % turn off output channel loadings for this
            
            assert(length(sequence.burn_times)==2 && ...
                   length(sequence.burn_amplitudes)==2 && ...
                   length(sequence.wait_times)==4);
            if 2*sequence.input_rise_time > sequence.wait_times(1)
                error('increase wait between burn pulses or decrease rise time')
            end
            if 2*sequence.input_rise_time > sequence.wait_times(3) || ...
                    2*sequence.freq_rise_time > sequence.wait_times(3)
                error('increase prescan wait time or decrease rise time')
            end
            if 2*sequence.input_rise_time > sequence.wait_times(4) || ...
                    2*sequence.freq_rise_time > sequence.wait_times(4)
                error('increase postscan wait time or decrease rise time')
            end
            
            %% burn
            burn_pair_loop_step = obj.make_burn_pair_step_loop(sequence.burn_amplitudes,...
                            sequence.burn_times, sequence.wait_times(1:2), ...
                            sequence.num_burn_loops, sequence.freq_rise_time, ...
                            sequence.input_rise_time, sequence.hole_freq_offset, ...
                            sequence.wait_freq_offset);
            obj.append_to_sequence(burn_pair_loop_step);
            
            %% wait
            prescan_wait_steps = obj.frac_n_make_wait_step(sequence.wait_times(3), ...
                                                   sequence.wait_freq_offset, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(prescan_wait_steps);
            
            %% scan
            scan_step = obj.make_scan_n_triggersync_step(sequence.freq_rise_time,...
                            sequence.input_rise_time, sequence.scan_time,...
                            sequence.scan_freq_range, sequence.scan_amplitude,...
                            sequence.wait_freq_offset);
            obj.append_to_sequence(scan_step);
            
            %% wait
            postscan_wait_steps = obj.frac_n_make_wait_step(sequence.wait_times(4), ...
                                                   sequence.wait_freq_offset, 0, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(postscan_wait_steps);
            

            %% run stuff
            obj.current_steps = [burn_pair_loop_step, prescan_wait_steps, ...
                                 scan_step, postscan_wait_steps];
            obj.current_sequence = sequence;
            obj.close_sequence_loop();
            obj.Awg_instance.start_output([obj.input_channel_num,obj.freq_channel_num]);
            if obj.output_channel_on
                obj.Awg_instance.start_output(obj.output_channel_num)
            end
        end
        function run_accumulated_afc_echo(obj, sequence)
            % burns and then scans an afc at 0 frequency detuning of the laser
            % A _sequence_ struct is presumed to contain:
            %     burn_amplitudes - height of [first,second] pulses
            %     burn_times - width of [first,second] pulses in ms
            %     wait_times - wait time after [pulse1,pulse2,before scan,each readouts,after scan] in ms
            %     scan_time - time for linear region of scan
            %     num_burn_loops - number of times to send in burn pairs
            %     input_rise_time - rise time for input signal (reduce ringing)
            %     out_rise_time - rise time for output signal (reduce ringing)

            %     read_amplitude - amplitude (to AOM) of read pulse between 0,1
            %     read_time - time duration of the read pulse
            %     num_read_loops - number of reads per AFC
                        
            obj.clean_for_new_sequence();
            obj.output_channel_on = 0; % turn off output channel loadings for this
            
            assert(length(sequence.burn_times)==2 && ...
                   length(sequence.burn_amplitudes)==2 && ...
                   length(sequence.wait_times)==5);
            if sequence.wait_times(3) < obj.trigger_time
                warning([ 'Not enough time to trigger the MEMS switch between burn and'...
                 ' readout pulses. Wait must currently be >' num2str(obj.trigger_time) ' ms'])
            end
            
            %% burn
            burn_pair_loop_step = obj.make_burn_pair_step_loop(sequence.burn_amplitudes,...
                            sequence.burn_times, sequence.wait_times(1:2), ...
                            sequence.num_burn_loops, 0, sequence.input_rise_time, 0, 0);
                            
            obj.append_to_sequence(burn_pair_loop_step);
            
            %% wait
            prescan_wait_steps = obj.frac_n_make_wait_step(sequence.wait_times(3), ...
                                        0, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(prescan_wait_steps);
            
            %% read
            if sequence.block_readout_step == 0
                readout_output = obj.output_pass;
            else
                readout_output = obj.output_block;
            end
            
            readout_step = obj.make_readout_step(sequence.read_amplitude,...
                            sequence.read_time, sequence.wait_times(4), ...
                            0, readout_output, sequence.num_read_loops);
            obj.append_to_sequence(readout_step);
            
            %% wait
            postscan_wait_steps = obj.frac_n_make_wait_step(sequence.wait_times(5),...
                             0, obj.output_pass, obj.MEMS_pass_output); % 1 for output
            obj.append_to_sequence(postscan_wait_steps);

            %% run stuff
            obj.current_steps = [burn_pair_loop_step, prescan_wait_steps, ...
                readout_step, postscan_wait_steps];
            obj.current_sequence = sequence;
            obj.close_sequence_loop();
            obj.Awg_instance.start_output([obj.input_channel_num,obj.freq_channel_num]);
            if obj.output_channel_on
                obj.Awg_instance.start_output(obj.output_channel_num)
            end
        end
        function run_echo(obj, sequence)
            % runs an echo at 0 frequency detuning of the laser
            % keeps MEMS switch open at all times (output_channel not used)
            %
            % A _sequence_ struct is presumed to contain:
            %     burn_amplitudes - height of [first,second,(third)] pulses
            %         amplitudes(3)=0 or length(amplitudes)=2 sets 2 pulse echo
            %     total_time - total time of the run (sum of next 3 values + end buffer)
            %     burn_times - width of [first,second,(third)] pulses in ms
            %         burn_times(3)=0 or length(burn_times)=2 sets 2 pulse echo
            %     wait12 - time between end of first and start of second pulse
            %     waitT - time between end of second and start of third pulse
            %     input_rise_time - rise time for input signal (reduce ringing)
            %     output_rise_time - rise time for output signal (reduce ringing)
            obj.clean_for_new_sequence();
            obj.output_channel_on = 1;  % turn on output channel loadings for this

            assert( sequence.input_rise_time < sequence.wait12 || ...
                max(sequence.input_rise_time, sequence.wait12) == 0); % otherwise you can't turn things on and off
            assert( sequence.output_rise_time < sequence.wait12 || ...
                max(sequence.output_rise_time, sequence.wait12) == 0 ); % otherwise you won't see the echo
            assert( length(sequence.burn_amplitudes)==length(sequence.burn_times) );
            
            obj.check_rounding([sequence.burn_times sequence.wait12 sequence.waitT]);
            
            intermission_time = sequence.total_time - sum(sequence.burn_times)...
                - sequence.wait12 - sequence.waitT;

            sync_trigger_step = obj.make_sync_trigger_step(0, 1);
            obj.append_to_sequence(sync_trigger_step);
            
            if sequence.burn_times(1)>0
                first_burn_step = obj.frac_n_make_burn_step(0, sequence.input_rise_time,...
                                        sequence.burn_times(1),sequence.burn_amplitudes(1),0,0,obj.output_pass,obj.MEMS_pass_output);
                obj.append_to_sequence(first_burn_step);
            end
            
            wait_tau12_step = obj.frac_n_make_wait_step(sequence.wait12, 0, obj.output_pass, obj.MEMS_pass_output);
            obj.append_to_sequence(wait_tau12_step);

            if sequence.burn_times(2)>0
                second_burn_step = obj.frac_n_make_burn_step(0, sequence.input_rise_time,...
                                        sequence.burn_times(2),sequence.burn_amplitudes(2),0,0,obj.output_pass,obj.MEMS_pass_output);
                obj.append_to_sequence(second_burn_step);
            end
            
            listen_step = obj.frac_n_make_wait_step(intermission_time, 0, obj.output_pass, obj.MEMS_pass_output);
            
            if length(sequence.burn_amplitudes) == 3 ... 
                     && length(sequence.burn_times) == 3 && sequence.burn_times(3)~=0
                assert( 2*sequence.input_rise_time < sequence.waitT );
                wait_T_step = obj.frac_n_make_wait_step(sequence.waitT, sequence.wait_freq_offset, obj.output_pass, obj.MEMS_pass_output);
                obj.append_to_sequence(wait_T_step);
                
                third_burn_step = obj.frac_n_make_burn_step(0, sequence.input_rise_time,...
                                        sequence.burn_times(3),sequence.burn_amplitudes(3),0,0,obj.output_pass,obj.MEMS_pass_output);
                obj.append_to_sequence(third_burn_step);
                obj.current_steps = [sync_trigger_step, first_burn_step, wait_tau12_step, ...
                    second_burn_step, wait_T_step, third_burn_step, listen_step];
            else
                if sequence.burn_times(1)==0
                    obj.current_steps = [sync_trigger_step, wait_tau12_step, ...
                        second_burn_step, listen_step];
                elseif sequence.burn_times(2)==0
                    obj.current_steps = [sync_trigger_step, first_burn_step, wait_tau12_step, ...
                        listen_step];
                else
                    obj.current_steps = [sync_trigger_step, first_burn_step, wait_tau12_step, ...
                        second_burn_step, listen_step];
                end
            end
            
            obj.append_to_sequence(listen_step);
            
            %% run stuff
            obj.current_sequence = sequence;
            obj.close_sequence_loop();
            obj.Awg_instance.start_output([obj.input_channel_num, obj.freq_channel_num]);
            if obj.output_channel_on
                obj.Awg_instance.start_output(obj.output_channel_num);
            end
        end
        % make___step: if the step doesn't exist, it is created and added
        % to the list of loaded waveforms after the waveform is uploaded.
        % This does NOT add it to the current sequence
        function burn_steps = frac_n_make_burn_step(obj, freq_rise_time, ...
                                    input_rise_time,burn_time,burn_amplitude,...
                                    hole_freq_offset,wait_freq_offset,output,MEMS)
            % conditionally split the wait time into blocks of length obj.max_flat_time
            if burn_time > 2*obj.max_flat_time
                num_loops = floor(burn_time / obj.max_flat_time);
                remainder = mod(burn_time, obj.max_flat_time);

                if freq_rise_time > 0
                    burn_pre = make_burn_ramp_step(obj, freq_rise_time, ...
                                            input_rise_time,burn_amplitude,...
                                            hole_freq_offset,wait_freq_offset,output,MEMS,1);
                    burn_pre.num_loops = 1;
                    
                    burn_post = make_burn_ramp_step(obj, freq_rise_time, ...
                                            input_rise_time,burn_amplitude,...
                                            hole_freq_offset,wait_freq_offset,output,MEMS,0);
                    burn_post.num_loops = 1;
                end
                                                    % this 0 for output channel ->
                burn_loop = make_flat_step(obj, obj.max_flat_time, burn_amplitude, ...
                                            hole_freq_offset,output,MEMS);
                burn_loop.num_loops = num_loops;
                
                if remainder > 0       % don't make an empty wait step
                                                    % this 0 for output channel ->
                    burn_remainder = make_flat_step(obj, remainder, burn_amplitude,...
                                            hole_freq_offset,output,MEMS);
                    burn_remainder.num_loops = 1;
                    if freq_rise_time > 0
                        burn_steps = [burn_pre burn_loop burn_remainder burn_post];
                    else
                        burn_steps = [burn_loop burn_remainder];
                    end
                else
                    if freq_rise_time > 0
                        burn_steps = [burn_pre burn_loop burn_post];
                    else
                        burn_steps = burn_loop;
                    end
                end
            else
                burn_steps = make_full_burn_step(obj, freq_rise_time, ...
                                        input_rise_time,burn_time,burn_amplitude,...
                                        hole_freq_offset,wait_freq_offset,output,MEMS);
            end
        end
        function burn_steps = frac_n_make_burn_trench_step(obj,  freq_mod_period, ...
                                    input_rise_time,burn_time,burn_amplitude,...
                                    trench_fraction)
            % conditionally split the wait time into blocks of length obj.max_flat_time
            actual_burn_time=round(burn_time/(freq_mod_period/2))*(freq_mod_period/2);
            
            if actual_burn_time ~= burn_time
               warning(['burn time input was ', num2str(burn_time), ...
                   ' burn time actually used is ' num2str(actual_burn_time)])
            end
            
            burn_time=actual_burn_time;
            freq_rise_time=freq_mod_period/2;
            
            if actual_burn_time < freq_mod_period
                error('burn time must be >= frequency modulation period')
            end
            
            num_loops = floor((burn_time-freq_mod_period)/freq_mod_period);
            
            odd_half_periods=mod(burn_time/(freq_mod_period/2),2);
            
            burn_pre = make_burn_trench_ramp_step(obj, freq_rise_time, ...
                                            input_rise_time,burn_amplitude,...
                                            trench_fraction,1,0);
            burn_pre.num_loops = 1;
            
            if burn_time > 3*freq_rise_time
                burn_loop = make_cosine_step(obj,freq_mod_period,...
                    freq_mod_period,trench_fraction,burn_amplitude);
                burn_loop.num_loops = num_loops;
            else
                burn_loop = [];
            end
                
            if odd_half_periods
            
                burn_post = make_burn_trench_ramp_step(obj, freq_rise_time, ...
                                                input_rise_time,burn_amplitude,...
                                                trench_fraction,0,1);
                burn_extra_halfcos = make_cosine_step(obj,freq_mod_period/2,...
                freq_mod_period,trench_fraction,burn_amplitude);
                burn_extra_halfcos.num_loops = 1;

                burn_steps = [burn_pre burn_loop burn_extra_halfcos burn_post];
            else
                burn_post = make_burn_trench_ramp_step(obj, freq_rise_time, ...
                                                input_rise_time,burn_amplitude,...
                                                trench_fraction,0,0);
                burn_post.num_loops = 1; 
                burn_steps = [burn_pre burn_loop burn_post];
            end
        end
        function burn_steps = make_full_burn_step(obj, freq_rise_time, ...
                                    input_rise_time,burn_time,burn_amplitude,...
                                    hole_freq_offset,wait_freq_offset,output,MEMS)
            name = ['brn' num2str(freq_rise_time) 'fqrs,' ...
                                num2str(input_rise_time) 'inrs,' ...
                                num2str(burn_time) 'tm,' ...
                                num2str(burn_amplitude) 'brnpw,' ...
                                num2str(hole_freq_offset) 'hofs,' ...
                                num2str(wait_freq_offset) 'wofs'];
            freq_rise_samples = freq_rise_time * obj.sample_rate;
            input_rise_samples = input_rise_time * obj.sample_rate;
            burn_samples = round(burn_time * obj.sample_rate);
            amp_wave = [zeros(1,freq_rise_samples-input_rise_samples),...
                    burn_amplitude * (0:1/(input_rise_samples-1):1),...
                    burn_amplitude * ones(1,burn_samples),...
                    burn_amplitude * (1:-1/(input_rise_samples-1):0),...
                    zeros(1,freq_rise_samples-input_rise_samples)];
            freq_wave = [flat2flat_transition(freq_rise_samples, ...
                    wait_freq_offset, hole_freq_offset),...
                    hole_freq_offset*ones(1,burn_samples),...
                    flat2flat_transition(freq_rise_samples, ...
                    hole_freq_offset,wait_freq_offset)];
            
            % zero for output_marker, scan_marker, sync_marker, MEMS_marker
            Os = zeros(size(amp_wave));
            burn_steps = obj.make_generic_step(name, amp_wave, freq_wave, ...
                                               output+Os, Os, Os, MEMS+Os);
            burn_steps.num_loops = 1;
        end
        function burn_steps = make_full_burn_step_trench(obj, freq_mod_period, ...
                                    input_rise_time,burn_time,burn_amplitude,...
                                    trench_fraction)
            name = ['brn' num2str(freq_mod_period) 'fqmp,' ...
                                num2str(input_rise_time) 'inrs,' ...
                                num2str(burn_time) 'tm,' ...
                                num2str(burn_amplitude) 'brnpw,' ...
                                num2str(trench_fraction) 'trfrc,'];
            
            actual_burn_time=round(burn_time/(freq_mod_period/2))*(freq_mod_period/2);
            
            if actual_burn_time ~= burn_time
               warning(['burn time input was ', num2str(burn_time), ...
                   ' burn time actually used is ' num2str(actual_burn_time)])
            end
            burn_time=actual_burn_time;
            odd_half_periods=mod(burn_time/(freq_mod_period/2),2);
            
            input_rise_samples = input_rise_time * obj.sample_rate;
            burn_samples = (burn_time * obj.sample_rate);
            freq_mod_period_samples=freq_mod_period * obj.sample_rate;
            amp_wave = [burn_amplitude * (0:1/(input_rise_samples-1):1),...
                    burn_amplitude * ones(1,burn_samples),...
                    burn_amplitude * (1:-1/(input_rise_samples-1):0)];
            
            if odd_half_periods
            freq_wave = [zeros(1,input_rise_samples),...
                    flat2flat_transition(freq_mod_period_samples/2, ...
                    0, trench_fraction),...
                    cos_freq_mod(trench_fraction,freq_mod_period_samples,burn_samples-freq_mod_period_samples),...
                    flat2flat_transition(freq_mod_period_samples/2, ...
                    -trench_fraction,0),...
                    zeros(1,freq_rise_samples-input_rise_samples)];
            else
            freq_wave = [zeros(1,input_rise_samples),...
                    flat2flat_transition(freq_mod_period_samples/2, ...
                    0, trench_fraction),...
                    cos_freq_mod(trench_fraction,freq_mod_period_samples,burn_samples-freq_mod_period_samples),...
                    flat2flat_transition(freq_mod_period_samples/2, ...
                    trench_fraction,0),...
                    zeros(1,freq_rise_samples-input_rise_samples)];
            end
            
            % zero for output_marker, scan_marker, sync_marker, MEMS_marker
            Os = zeros(size(amp_wave));
            burn_steps = obj.make_generic_step(name, amp_wave, freq_wave, ...
                                               obj.output_block+Os, Os, Os, obj.MEMS_block_output+Os);
            burn_steps.num_loops = 1;
        end
        function burn_step = make_burn_ramp_step(obj, freq_rise_time, ...
                                    input_rise_time,burn_amplitude,...
                                    hole_freq_offset,wait_freq_offset,output,MEMS,up_not_down)
            name = [num2str(freq_rise_time) 'fqrs,' ...
                    num2str(input_rise_time) 'inrs,' ...
                    num2str(burn_amplitude) 'brnpw,' ...
                    num2str(hole_freq_offset) 'hofs,' ...
                    num2str(wait_freq_offset) 'wofs'];
            freq_rise_samples = freq_rise_time * obj.sample_rate;
            input_rise_samples = input_rise_time * obj.sample_rate;
            amp_wave = [zeros(1,freq_rise_samples-input_rise_samples),...
                    burn_amplitude * (0:1/(input_rise_samples-1):1)];
            freq_wave = flat2flat_transition(freq_rise_samples, ...
                    wait_freq_offset, hole_freq_offset);
            % output gate, sync, and scan marker are both zero for burn pulses
            Os = zeros(size(amp_wave));
            if up_not_down
                burn_step = obj.make_generic_step(['brn-up' name], amp_wave, freq_wave,...
                               output+Os, Os, Os, MEMS+Os);
            else
                burn_step = obj.make_generic_step(['brn-dwn' name], ...
                                fliplr(amp_wave), fliplr(freq_wave), ...
                              output+Os, Os, Os, MEMS+Os);
                            
            end
            burn_step.num_loops = 1;
        end
        function burn_step = make_burn_trench_ramp_step(obj, freq_rise_time, ...
                                    input_rise_time,burn_amplitude,...
                                    trench_fraction,up_not_down,odd)
            name = [num2str(freq_rise_time) 'fqrs,' ...
                    num2str(input_rise_time) 'inrs,' ...
                    num2str(burn_amplitude) 'brnpw,' ...
                    num2str(trench_fraction) 'trfr' ...
                    num2str(up_not_down) 'und,' ...
                    num2str(odd) 'odd'];
            freq_rise_samples = freq_rise_time * obj.sample_rate;
            input_rise_samples = input_rise_time * obj.sample_rate;
            if freq_rise_samples < input_rise_samples
                error(['freq_rise_samples (' num2str(freq_rise_samples) ...
                    ') must be greater than input_rise_samples (' ...
                    num2str(input_rise_samples) ')'])
            end
            amp_wave = [burn_amplitude * (0:1/(input_rise_samples-1):1),...
                       burn_amplitude * ones(1,freq_rise_samples-input_rise_samples)];
            freq_wave = flat2flat_transition(freq_rise_samples, ...
                    0, trench_fraction);
            % output gate, sync, and scan marker are both zero for burn pulses
            Os = zeros(size(amp_wave));
            if up_not_down
                burn_step = obj.make_generic_step(['brn-up' name], ...
                                amp_wave, freq_wave, obj.output_block+Os, Os, Os, obj.MEMS_block_output+Os);
            elseif ~up_not_down && ~odd
                burn_step = obj.make_generic_step(['brn-dwn' name], ...
                                fliplr(amp_wave), fliplr(freq_wave), ...
                                obj.output_block+Os, Os, Os, obj.MEMS_block_output+Os);
            elseif ~up_not_down && odd
                burn_step = obj.make_generic_step(['brn-dwn' name], ...
                                fliplr(amp_wave), -fliplr(freq_wave), ...
                                obj.output_block+Os, Os, Os, obj.MEMS_block_output+Os);              
            end
            burn_step.num_loops = 1;
        end
        function burn_steps = make_burn_pair_step_loop(obj, burn_amplitudes, ...
                                    burn_times, wait_times, num_burn_loops, ...
                                    freq_rise_time, input_rise_time, ...
                                    hole_freq_offset, wait_freq_offset)
            % takes up sum(burn_times) + wait_times(1)+wait_times(2) and loops num_burn_loops times
            name = ['b' num2str(freq_rise_time) 'fqrs' ...
                                num2str(input_rise_time) 'inrs' ...
                                num2str(burn_times(1)) ',' ...
                                num2str(burn_times(2)) 'tm' ...
                                num2str(burn_amplitudes(1)) ',' ...
                                num2str(burn_amplitudes(2)) 'amp' ...
                                num2str(hole_freq_offset) 'hofs' ...
                                num2str(wait_freq_offset) 'wofs' ...
                                num2str(wait_times(1)) ',' ...
                                num2str(wait_times(2)) 'wt'];
            
            input_rise_samples = input_rise_time * obj.sample_rate;
            burn_samples = burn_times * obj.sample_rate;
            wait_samples = wait_times * obj.sample_rate;
            if hole_freq_offset == wait_freq_offset 
                freq_rise_samples = 0;
            else
                freq_rise_samples = freq_rise_time * obj.sample_rate;
            end
            
            % wait, transition to fully open when the frequency hits the target
            % burn the first pulse, come back down, wait, rise back up again
            % burn the second pulse, come down again
            amp_wave = [zeros(1,freq_rise_samples-input_rise_samples), ...
                   burn_amplitudes(1) * (0:1/(input_rise_samples-1):1),...
                   burn_amplitudes(1) * ones(1,burn_samples(1)), ...
                   burn_amplitudes(1) * (1:-1/(input_rise_samples-1):0),...
                   zeros(1,wait_samples(1)-2*input_rise_samples),  ...
                   burn_amplitudes(2) * (0:1/(input_rise_samples-1):1), ...
                   burn_amplitudes(2) * ones(1,burn_samples(2)),  ...
                   burn_amplitudes(2) * (1:-1/(input_rise_samples-1):0),...
                   zeros(1,wait_samples(2)-freq_rise_samples-input_rise_samples )];
            
            if hole_freq_offset == wait_freq_offset 
                freq_wave = hole_freq_offset * ones(size(amp_wave));
            else
                freq_wave = [flat2flat_transition(freq_rise_samples, wait_freq_offset, hole_freq_offset), ...
                         hole_freq_offset*ones(1,burn_samples(1)+wait_samples(1)+burn_samples(2)), ...
                         flat2flat_transition(freq_rise_samples,hole_freq_offset,wait_freq_offset), ...
                         wait_freq_offset*ones(1,wait_samples(2)-2*freq_rise_samples)];
            end
            % zero for output_marker, scan_marker, sync_marker, MEMS_marker
            Os = zeros(size(amp_wave));
            burn_steps = obj.make_generic_step(name, amp_wave, freq_wave, ...
                        obj.output_block+Os, Os, Os, obj.MEMS_block_output+Os);
            burn_steps.num_loops = num_burn_loops;
        end
        function burn_steps = make_stepNburn_step_loop(obj, burn_amplitude,...
                                    burn_time, wait_time, num_teeth, num_burn_loops,...
                                    freq_rise_time, input_rise_time, hole_freq_offset,...
                                    teeth_range, wait_freq_offset)
            name = ['b' num2str(num_teeth) 'teeth' ...
                                num2str(teeth_range(1)) ',' ...
                                num2str(teeth_range(2)) 'tr' ...
                                num2str(freq_rise_time) 'fqrs' ...
                                num2str(input_rise_time) 'inrs' ...
                                num2str(burn_time) 'tm' ...
                                num2str(burn_amplitude) 'amp' ...
                                num2str(hole_freq_offset) 'hofs' ...
                                num2str(wait_freq_offset) 'wofs' ...
                                num2str(wait_time) 'wt'];
            
            if freq_rise_time < wait_time
                error(['freq_rise_time (time from 0 to first freq) must'...
                    'be longer than the first value in wait_time (time'...
                    'to transition frequency between steps)'])
            end
                        
            input_rise_samples = input_rise_time * obj.sample_rate;
            burn_samples = burn_time * obj.sample_rate;
            wait_samples = wait_time * obj.sample_rate;
            freq_rise_samples = freq_rise_time * obj.sample_rate;
            
            % amplitude waits freq_rise_samples, and then alternates being on for
            % burn_samples and being off for wait_samples, rising with input-rise_samples
            % each time.
            amp_rect = [burn_amplitude * (0:1/(input_rise_samples-1):1),...
                        burn_amplitude * ones(1,burn_samples),...
                        burn_amplitude * (1:-1/(input_rise_samples-1):0),...
                        zeros(1,wait_samples)];
            amp_wave = [zeros(1,freq_rise_samples), repmat(amp_rect, 1, num_teeth),...
                        zeros(1,freq_rise_samples-wait_samples)];
            
            % frequency rises with freq_rise_samples to the first step, and then 
            % alternates waiting burn_samples and stepping in wait_samples to the next
            % value using flat2flat_transition
            if num_teeth > 1
                teeth_freqs = (teeth_range(1):range(teeth_range)/(num_teeth-1):teeth_range(2)) + hole_freq_offset;
            else
                teeth_freqs = hole_freq_offset;
            end
            freq_steps = num2cell(meshgrid(teeth_freqs, ...
                                    1:(burn_samples+2*input_rise_samples)),1);
            freq_moves = arrayfun(@flat2flat_transition, ...
                                  [freq_rise_samples, ...
                                      wait_samples*ones(1,num_teeth-1),...
                                      freq_rise_samples],...
                                  [wait_freq_offset, teeth_freqs], ...
                                  [teeth_freqs, wait_freq_offset], ...
                                  'UniformOutput', false);
            freq_wave = freq_moves{1};
            for index = 1:num_teeth % let it grow, LET IT GROW!!!
                freq_wave = [freq_wave freq_steps{index}' freq_moves{index+1} ]; %#ok<AGROW>
            end
            % zero for output_marker, scan_marker, sync_marker, MEMS_marker
            Os = zeros(size(amp_wave));
            burn_steps = obj.make_generic_step(name, amp_wave, freq_wave, ...
                obj.output_block+Os, Os, Os, obj.MEMS_block_output+Os);
            burn_steps.num_loops = num_burn_loops;
        end
        function readout_step = make_readout_step(obj, burn_amplitude,...
                            burn_time, wait_time, freq_offset, output, num_loops)
            % a readout step has the output open
            name = ['read' num2str(burn_time) 'tm' ...
                                num2str(burn_amplitude) 'amp' ...
                                num2str(wait_time) 'wt' ...
                                num2str(freq_offset) 'fqofs' ...
                                num2str(num_loops) 'numloops' ];
            burn_samples = burn_time * obj.sample_rate;
            wait_samples = wait_time * obj.sample_rate;
            amp_wave = burn_amplitude*[ones(1,burn_samples) zeros(1,wait_samples)];
            freq_wave = freq_offset * ones(size(amp_wave));
            scan_marker = amp_wave>0;
            sync_marker = [ones(1,burn_samples) zeros(1,wait_samples)];
            
            readout_step = obj.make_generic_step(name, ...
                repmat(amp_wave,[1, num_loops]), ...
                repmat(freq_wave,[1, num_loops]),...
                repmat(output*ones(size(amp_wave)),[1, num_loops]), ... %output_marker
                repmat(scan_marker,[1, num_loops]),... %repmat(zeros(size(amp_wave)),[1, num_loops]), ... %sync_marker
                repmat(sync_marker,[1, num_loops]), ...%sync marker IC
                repmat(obj.MEMS_pass_output*ones(size(amp_wave)),[1, num_loops])); ... %MEMS_marker
            readout_step.num_loops = 1; 
             % the actually repeated version is commented because 40000 of
             % anything makes the AWG ill
%             readout_step = obj.make_generic_step(name, amp_wave, freq_wave,...
%                     ones(size(amp_wave)), scan_marker, zeros(size(amp_wave)), ...
%                     ones(size(amp_wave)));
%             readout_step.num_loops = num_loops;
        end
        function sync_trigger_step = make_sync_trigger_step(obj, wait_freq_offset)
            % makes a step of length obj.trigger_time which triggers the MEMS switch and 
            % optionally triggers the sync_marker
            name = ['sync_' num2str(obj.trigger_time) 'trigtime,' ...
                          num2str(wait_freq_offset) 'wofs,'];
            trigger_samples = obj.sample_rate * obj.trigger_time;
            amp_wave = zeros(1,trigger_samples);
            freq_wave = wait_freq_offset * ones(size(amp_wave));
            output_wave = ones(size(amp_wave));
            scan_marker = zeros(size(amp_wave));
            sync_marker = sync_to_on * ones(1,trigger_samples);
            MEMS_marker = obj.MEMS_pass_output*ones(1,trigger_samples);
            sync_trigger_step = obj.make_generic_step(name, amp_wave, ...
                         freq_wave, output_wave, scan_marker, sync_marker, MEMS_marker);
            sync_trigger_step.num_loops = 1;
        end
        function scan_step = make_scan_n_triggersync_step(obj, freq_rise_time, input_rise_time, ...
                                       scan_time, scan_freq_range, scan_amplitude, wait_freq_offset)
            name = ['scn' num2str(freq_rise_time) 'fqrs,' ...
                          num2str(input_rise_time) 'inrs,' ...
                          num2str(scan_time) 'tm,' ...
                          num2str(scan_freq_range) 'scnrng,'...
                          num2str(scan_amplitude) 'scnpw'...
                          num2str(wait_freq_offset) 'wofs'];
            freq_rise_samples = freq_rise_time * obj.sample_rate;
            input_rise_samples = input_rise_time * obj.sample_rate;
            scan_samples = scan_time * obj.sample_rate;
            amp_wave = [zeros(1,freq_rise_samples-input_rise_samples) ...
                    scan_amplitude * (0:1/(input_rise_samples-1):1),...
                    scan_amplitude * ones(1,scan_samples),...
                    scan_amplitude * (1:-1/(input_rise_samples-1):0)...
                    zeros(1,freq_rise_samples-input_rise_samples)];
            freq_wave = smooth_transition_scan(2*freq_rise_samples...
                    +scan_samples, scan_samples, scan_freq_range,wait_freq_offset);
            output_wave = obj.output_pass*ones(size(amp_wave));
            scan_marker = [ones(1,floor(length(amp_wave)/2)) ...
                           zeros(1,ceil(length(amp_wave)/2)) ];
            trigger_samples = obj.trigger_time * obj.sample_rate;
            sync_marker = [ones(1,trigger_samples), zeros(1,length(scan_marker)-trigger_samples)];
            MEMS_marker = obj.MEMS_pass_output*ones(size(amp_wave));
            scan_step = obj.make_generic_step(name, amp_wave, freq_wave, output_wave, ...
                                              scan_marker, sync_marker, MEMS_marker);
            scan_step.num_loops = 1;
        end
        function wait_steps = frac_n_make_wait_step(obj, flat_time, freq_offset, output, MEMS)
            if flat_time <= 0 % so that it doesn't die for wait_time == rise_time/2
                wait_steps = [];
            else
                % split the wait time into blocks of length obj.max_flat_time
                num_loops = floor(flat_time / obj.max_flat_time);
                remainder = mod(flat_time, obj.max_flat_time);

                if num_loops > 0
                    wait_loop = obj.make_flat_step(obj.max_flat_time, 0, freq_offset,output,MEMS);
                    wait_loop.num_loops = num_loops;
                end

                if remainder > 0       % don't make an empty wait step
                    wait_remainder = obj.make_flat_step(round(remainder,10), 0, freq_offset,output,MEMS);
                    wait_remainder.num_loops = 1;
                    if num_loops > 0
                        wait_steps = [wait_remainder wait_loop];
                    else
                        wait_steps = wait_remainder;
                    end
                else
                    wait_steps = wait_loop;
                end
            end
        end
        function flat_step = make_flat_step(obj, flat_time, amplitude, freq_offset,output,MEMS)
            % a flat step is assumed to have 1 in the mems marker and 0 in the sync marker, 
            % thus triggering neither.  To actually trigger, use make_readout_step
            name = ['flat' num2str(flat_time) ',' ...
                        num2str(amplitude) 'amp,' ...
                        num2str(freq_offset) 'frqofst'];
            % flat_samples = round(flat_time) * obj.sample_rate;  %%%%%%% pretty sure this was wrong
            flat_samples = round(flat_time * obj.sample_rate);
            amp_wave = amplitude * ones(1,flat_samples);
            output_wave = output * ones(size(amp_wave));
            freq_wave = freq_offset * ones(1,flat_samples);
            scan_marker = zeros(size(amp_wave));
            sync_marker = zeros(size(amp_wave));
            MEMS_marker = MEMS*ones(size(amp_wave));
            flat_step = obj.make_generic_step(name, amp_wave, freq_wave, output_wave, ...
                                              scan_marker, sync_marker, MEMS_marker);
        end
        
        function cosine_step = make_cosine_step(obj,cosine_time,freq_mod_period,freq_amplitude,amplitude)
            % a flat step is assumed to have 1 in the mems marker and 0 in the sync marker, 
            % thus triggering neither.  To actually trigger, use make_readout_step
            name = ['cos' num2str(cosine_time) ',' ...
                        num2str(freq_amplitude) 'trfr,' ...
                        num2str(amplitude) 'amp'];
            % flat_samples = round(flat_time) * obj.sample_rate;  %%%%%%% pretty sure this was wrong
            cosine_samples = cosine_time * obj.sample_rate;
            freq_mod_period_samples = freq_mod_period * obj.sample_rate;
            amp_wave = amplitude * ones(1,cosine_samples);
            output_wave = obj.output_block * ones(size(amp_wave));
            freq_wave = freq_amplitude * cos(2*pi*(1:cosine_samples)/freq_mod_period_samples);
            scan_marker = zeros(size(amp_wave));
            sync_marker = zeros(size(amp_wave));
            MEMS_marker = obj.MEMS_block_output*ones(size(amp_wave));
            cosine_step = obj.make_generic_step(name, amp_wave, freq_wave, output_wave, ...
                                              scan_marker, sync_marker, MEMS_marker);
        end
        
        function step = make_generic_step(obj, name, amp, freq, output, scan_marker, sync_marker, MEMS_marker)
            name = strrep(name, '0.', '.');
            if length(name)>=64
                error(['step name "' name '" is too long.  ruh roh...);']);
            end
            if ~obj.is_name_loaded(name)
                step.name = name;
                step.amp_wave = amp;
                step.freq_wave = freq;
                step.input_marker = amp>0;      % shows when input is on
                step.sync_marker = sync_marker;
                step.scan_marker = scan_marker;
                step.MEMS_marker = MEMS_marker;
                step.output_wave = output;
                step.output_marker = output>0;  % shows when output_wave is on
                obj.upload_step(step)
            else
                step = obj.get_step_from_name(name);
            end
        end

        function loaded = is_name_loaded(obj, name)
            loaded = false;
            for loadedstep = obj.loaded_steps
                if ~isempty(loadedstep)
                    loaded = loaded || strcmp(name, loadedstep{1}.name);
                end
            end
        end
        function step = get_step_from_name(obj, step_name)
            for loadedstep = obj.loaded_steps
                if strcmp(loadedstep{1}.name, step_name)
                    step = loadedstep{1};
                    break
                end
            end
        end
        function upload_step(obj, step)
            % loads the frequency and amplitude components into the AWG
            % also chooses which markers to load for each step
            % currently set to upload input_marker to marker2 and either
            % scan or output marker to amp&freq or output waves for marker 1, respectively
            if length(step.amp_wave)~=length(step.input_marker) || ...
               length(step.amp_wave)~=length(step.sync_marker) || ...
               length(step.amp_wave)~=length(step.scan_marker) || ...
               length(step.amp_wave)~=length(step.MEMS_marker)
                error(['Size mismatch on generated waveforms for ' ...
                       step.name '  If you reached this using a '...
                       'Sequence_loader function, you''ve earned a '...
                       'phone-a-friend: 949-370-0707.'])
            end
            
            obj.loaded_steps{length(obj.loaded_steps)+1} = step;
            obj.Awg_instance.create_waveform(strcat('a_',step.name),...
                            step.amp_wave, step.input_marker, step.sync_marker); 
            obj.Awg_instance.create_waveform(strcat('f_',step.name),...
                            step.freq_wave, step.scan_marker, step.MEMS_marker);
            if obj.output_channel_on
                obj.Awg_instance.create_waveform(strcat('o_',step.name),...
                            step.output_wave, step.output_marker, step.input_marker);
            end
            obj.total_loaded_points = obj.total_loaded_points + ...
                                      length(step.amp_wave)*(2+obj.output_channel_on);
            if obj.verbose
                if obj.output_channel_on
                    disp(['   uploaded amp,freq,&output for step: ' step.name]);
                else
                    disp(['   uploaded amp&freq for step: ' step.name]);
                end
            end
        end
        function append_to_sequence(obj, steps)
            % Adds steps by name to the end of the sequence.  Assumes names are unique identifiers, and waveforms by
            % those names have already been uploaded to the AWG
            for step = steps
                step_num = obj.Awg_instance.get_sequence_num_steps()+1;
                obj.Awg_instance.set_sequence_num_steps(step_num);
                obj.Awg_instance.set_channel_waveform_seq_step(obj.input_channel_num,step_num,['a_' step.name]);
                obj.Awg_instance.set_channel_waveform_seq_step(obj.freq_channel_num,step_num,['f_' step.name]);
                if obj.output_channel_on
                    obj.Awg_instance.set_channel_waveform_seq_step(obj.output_channel_num,step_num,['o_' step.name]);
                end
                assert(isfield(step,'num_loops'))
                if step.num_loops ~= 1
                    obj.Awg_instance.set_channel_seq_step_loop_num(step_num, step.num_loops)
                end
                if obj.verbose
                    disp(['   appended step: ' step.name ' (loop:' num2str(step.num_loops) ')']);
                end
                pause(.5)
            end
        end
        function close_sequence_loop(obj)
            num_steps = obj.Awg_instance.get_sequence_num_steps();
            obj.Awg_instance.set_sequence_step_goto(num_steps,1);
        end
        function plot_handle = plot_current(obj,downsample_factor)
            channel_a_waveform = [];             channel_b_waveform = [];
            sync_marker_waveform = [];           input_marker_waveform = [];
            scan_marker_waveform = [];           MEMS_marker_waveform = [];
            channel_c_waveform = [];             output_marker_waveform = [];

            for step = obj.current_steps
                channel_a_waveform = [channel_a_waveform downsample(repmat(step.amp_wave, ...
                                      [1, step.num_loops]),downsample_factor)]; %#ok<AGROW>
                channel_b_waveform = [channel_b_waveform downsample(repmat(step.freq_wave, ...
                                      [1, step.num_loops]),downsample_factor)]; %#ok<AGROW>
                input_marker_waveform = [input_marker_waveform downsample(repmat(step.input_marker, ...
                                    [1, step.num_loops]),downsample_factor)]; %#ok<AGROW>
                sync_marker_waveform = [sync_marker_waveform downsample(repmat(step.sync_marker, ...
                                    [1, step.num_loops]),downsample_factor)]; %#ok<AGROW>
                scan_marker_waveform = [scan_marker_waveform downsample(repmat(step.scan_marker, ...
                                    [1, step.num_loops]),downsample_factor)]; %#ok<AGROW>
                MEMS_marker_waveform = [MEMS_marker_waveform downsample(repmat(step.MEMS_marker, ...
                                    [1, step.num_loops]),downsample_factor)]; %#ok<AGROW>
                if obj.output_channel_on
                    channel_c_waveform = [channel_c_waveform downsample(repmat(step.output_wave, ...
                                    [1, step.num_loops]),downsample_factor)]; %#ok<AGROW>
                    output_marker_waveform = [output_marker_waveform downsample(repmat(step.output_marker, ...
                                    [1, step.num_loops]),downsample_factor)]; %#ok<AGROW>
                end
            end
            plot_handle = figure();
            total_samples = length(scan_marker_waveform);
            x = (1:total_samples)/obj.sample_rate/1000*downsample_factor;
            plot(x, channel_a_waveform, x, channel_b_waveform, x, input_marker_waveform, x, sync_marker_waveform, ...
                 x, scan_marker_waveform, x, MEMS_marker_waveform);
            xlabel('seconds')
            ylabel('volts')
            if obj.output_channel_on
                hold on
                plot(x, channel_c_waveform, x, output_marker_waveform)
                hold off
                legend('input open', 'frequency offset', 'RF switch', 'sync marker', 'scan trigger', ...
                    'MEMS trigger', 'output wave','Location','SouthEast');
            else
                legend('input open', 'frequency offset', 'RF switch', 'sync marker', 'scan trigger', ...
                    'Location','SouthEast');
            end
        end
        function vector = concat_waveform(cells)
            vector = [];
            for index = 1:length(cells)
                vector = [vector cells{index}]; %#ok<AGROW>
            end
        end
        
        function check_rounding(obj, time_vector)
            for time = time_vector
                num_samples = time * obj.sample_rate;
                if mod(num_samples,1)~=0
                    warning(['may be rounding value ' num2str(time) ' ms by ' ...
                        num2str(time - round(num_samples)/obj.sample_rate) ' ms'])
                end
            end
        end
    end
end