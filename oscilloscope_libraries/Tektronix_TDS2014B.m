% Tektronix AWG2014 object
% 
% built from a few sources
%   http://www1.tek.com/forum/viewtopic.php?f=6&t=3217
%   AWG2014 programmer manual from online saved in fgen_libraries
%   Jon's implementation of the 2024c Tex mdd file readscope
% 
% does not implement possible trigger commands
%         % to get list of settings that can be configured
%         set(osc)
%         % to get the current configuration of the oscilloscope
%         get(osc)
%         % configuring trigger (as example of setting up scope)
%         trigger_group = get(osc, 'Trigger');
%         % use get command to read property
%         get(trigger_group, 'Slope' );
%         % use set command to set.
%         set(trigger_group, 'Slope', 'falling');
%         % can get list of other properties using
%         get(trigger_group)
% 
% usage:
% Scope_instance = Tektronix_AWG5014(1)
% Scope_instance.get_waveform(2);
% 
% ETM 20151130

classdef (ConstructOnLoad = true) Tektronix_TDS2014B < handle
    properties (SetAccess = private)
        tds_obj;
        buffer_size;
        acq_obj;
        waveform_group;
        chan_obj;
        num_values = 2500;
        channels_on;
    end
    methods
        function obj = Tektronix_TDS2014B(address)
            
            if ischar(address)
                instr_address = address;
            else
                instr_address = 'USB0::0x0699::0x0368::C034313::0::INSTR';
            end
            
            % Find a VISA-USB object.
            instr_visa = instrfind('Type', 'visa-usb', 'RsrcName', instr_address, 'Tag', '');

%             % in case it doesn't work, try this
%             visa = visa('AGILENT', 'USB0::0x0699::0x0368::C034313::0::INSTR');
%             obj.tds_obj =  icdevice('tektronix_tds2014.mdd', visa);
%             disconnect(obj.tds_obj)
%             delete(obj.tds_obj)
            
            
            % Create the VISA-USB object if it does not exist
            % otherwise use the object that was found.
            if isempty(instr_visa)
                instr_visa = visa('AGILENT', instr_address);
            else
                fclose(instr_visa);
                instr_visa = instr_visa(1);
            end
            
            obj.tds_obj = icdevice('tektronix_tds2014.mdd', instr_visa);
            
            % Connect device object to hardware.
            connect(obj.tds_obj);
            
            obj.acq_obj = get(obj.tds_obj,'Acquisition');
            wvfm_group = get(obj.tds_obj, 'Waveform');
            obj.waveform_group = wvfm_group(1);
            obj.chan_obj = get(obj.tds_obj,'Channel');

            for channel = 1:4
                obj.channels_on(channel) = strcmp(obj.chan_obj.State(channel),'on');
            end
        end
        
        %% control
    	function close(obj)
            disconnect(obj.tds_obj);
            delete(obj.tds_obj);
        end
        % check every 100 ms to make sure the scope is not busy before 
        % continuing.  Breaks after max_time_sec
        function finish_last_command(obj, max_time_sec)
            warning('this command doesn''t seem to work')
            for i=1:max_time_sec/10;
                if ~obj.tds_obj.Busy
                    return;
                end
                pause(10)
            end
            warning('command did not finish in allotted time')
        end
        %% getters
        function acq_settings = get_acquisition_settings(obj)
            acq_settings = obj.acq_obj;
        end
        function chan_settings = get_channel_settings(obj)
            chan_settings = obj.chan_obj;
        end
        function [X, Y] = get_waveform(obj,channel_nums)
            if ~isempty(channel_nums)
                if isscalar(channel_nums)
                    [Y, X] = invoke(obj.waveform_group, ...
                            'readwaveform', ['channel' num2str(channel_nums)]);
                else
                    if max(channel_nums)>4 || min(channel_nums)<1
                        error('oh come on... channel numbers are 1-4')
                    end
                    Y = zeros(obj.num_values,4);
                    X = zeros(obj.num_values,4);
                    for channel_num = channel_nums
                        disp(['sending in ->channel' num2str(channel_num) '<-'])
                        [y, x] = invoke(obj.waveform_group, ...
                            'readwaveform', ['channel' num2str(channel_num)]);
                        Y(:,channel_num) = y;
                        X(:,channel_num) = x;
                    end
                end
            end
        end
        function channel_bits = get_channels_on(obj)
            channel_bits = obj.channels_on;
        end
        %% setters        
        function set_single_acquisition(obj)
            set(obj.acq_obj,'State','run')
            set(obj.acq_obj,'Control','single')
        end
        function set_num_averaging(obj, num_frames)
            set(obj.acq_obj,'NumberOfAverages',num_frames)
        end
        function set_timebase_seconds(obj, time)
                set(obj.acq_obj,'Timebase',time)
        end
        function set_timedelay_seconds(obj, time)
                set(obj.acq_obj,'Delay',time)
        end
        function set_channels_on(obj, channel_bits)
            if length(channel_bits)==4
                for channel_num = 1:4
                    if logical(channel_bits(channel_num))
                        set(obj.chan_obj(channel_num),'State','on');
                    else
                        set(obj.chan_obj(channel_num),'State','off');
                    end
                end
                obj.channels_on = channel_bits;
            else
                error('channel_bits must be 1x4, setting all channels');
            end
        end
        function set_voltage_scale(obj, V, channel_nums)
            for channel_num = channel_nums
                set(obj.chan_obj(channel_num),'Scale',V);
            end
        end
        function set_voltage_position(obj, V, channel_nums)
            for channel_num = channel_nums
                set(obj.chan_obj(channel_num),'Position',V);
            end
        end

    end
end
