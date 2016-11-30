% built from Tunics_TECL_obj.m and the matlab instrument control toolbox
% 
% DLCpro command reference on USB stick with laser manuals in the filecabinet
% copied to C:\Users\u2\Documents\Toptica documentation\1_TOPTICA DLC pro 
%     SOFTWARE_1.3.1\1_DOCUMENTATION\Toptica_DLCpro-Command-Reference
% 
% Most errors seem to be caused by the read buffer not being cleared 
% properly.  In the event of something weird, try messing with that either
% at the end of the constructor or in the method set_n_confirm()
% 
% ETM 20151016

classdef (ConstructOnLoad = true) Toptica_DLCpro_obj < handle
    properties (SetAccess = private)
        DLCpro_visa;
        bool_str = {'#f';'#t'}
    end
    methods
        function obj = Toptica_DLCpro_obj(address)
%             % uncomment for USB port
%             if nargin == 1
%                 if ~ischar(address)
%                     address = 'COM5';
%                     disp([ 'invalid address, using ' address ])
%                 end
%             end
%             instruments = instrfind('Type', 'serial', 'Port', 'COM5', 'Tag', '');
% 
%             if isempty(instruments) % Create the VISA-serial object if it does not exist
%                 obj.DLCpro_visa = serial(address);
%             else            % otherwise use the object that was found.
%                 fclose(instruments);
%                 obj.DLCpro_visa = instruments(1);
%             end
            
            % check naively that address is IP-like (doesn't check <255)
            if regexp(address,'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$')
                instr_address = address;
            else
                instr_address  = '131.215.48.207';
                warning('provided address invalid, using 131.215.48.207');
            end
            obj.DLCpro_visa = tcpip(instr_address, 1998);
            
            fopen(obj.DLCpro_visa);     % Connect to instrument object, obj.
            
            fprintf(obj.DLCpro_visa, '(param-set! ''echo #f)');
            flushinput(obj.DLCpro_visa);
            flushoutput(obj.DLCpro_visa);

%             echo = fscanf(obj.DLCpro_visa);
%             if echo ~= '0'
%                 disp('echo off is acting funny');
%                 if strcmp(echo,'(param-set! ''echo #f)') == 1
%                     disp('woah, boy.  acting real funny-like');
%                     echo = fscanf(obj.DLCpro_visa);
%                     if echo ~= '0'
%                         error(['something went sideways.  Should print 0 but got ' echo])
%                     end
%                 end
%                 fscanf(obj.DLCpro_visa);
%             end
        end
    	function close(obj)
            fclose(obj.DLCpro_visa);    % Disconnect all objects.
        end
        function start_sweep(obj)
        	fprintf(obj.DLCpro_visa, '(exec ''laser1:ctl:scan:start)');
        end
        function stop_sweep(obj)
        	fprintf(obj.DLCpro_visa, '(exec ''laser1:ctl:scan:stop)');
        end
        function pause_sweep(obj)
        	fprintf(obj.DLCpro_visa, '(exec ''laser1:ctl:scan:pause)');
        end
        function resume_sweep(obj) % can only resume a paused sweep
            fprintf(obj.DLCpro_visa, '(exec ''laser1:ctl:scan:continue)');
        end
        function sing(obj,song_num)
            if(song_num==1)
                fprintf(obj.DLCpro_visa, '(exec ''buzzer:play "AAAA   AA  A  AAAA  CC  B  BB  A  AAA  A  AAAAAA")');
            else
                fprintf(obj.DLCpro_visa, '(exec ''buzzer:play "EEEE    EEEE    EEEE    AAA  HH  EEEE    AAA  HH  EEEEEE      KKKK    KKKK    KKKK   LLL  GG  CCCC    AAA   GG  EEEEEE ")');
            end
        end
        %% getters
        function power = get_power_mW(obj)
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:ctl:power:power-act)');
            output = fscanf(obj.DLCpro_visa);
            power = str2double(output(3:end-2));
        end
        function current = get_current_mA(obj)
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:dl:cc:current-act)');
            output = fscanf(obj.DLCpro_visa);
            current = str2double(output(3:end-2));
        end
        function wavelength = get_wavelength_nm(obj)
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:ctl:wavelength-act)');
            output = fscanf(obj.DLCpro_visa);
            wavelength = str2double(output(3:end-2));
        end
        function voltage = get_piezo_actual_voltage(obj)
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:dl:pc:voltage-act)');
            output = fscanf(obj.DLCpro_visa);
            voltage = str2double(output(3:end-2));
        end
        function voltage = get_piezo_offset_voltage(obj)
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:scan:offset)');
            output = fscanf(obj.DLCpro_visa);
            voltage = str2double(output(3:end-1));
        end
        function sweep_bounds = get_motor_sweep_bounds(obj)
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:ctl:scan:wavelength-begin)');
            sweep_start = fscanf(obj.DLCpro_visa);
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:ctl:scan:wavelength-end)');
            sweep_end = fscanf(obj.DLCpro_visa);
            sweep_bounds = [str2double(sweep_start(3:end-2)) str2double(sweep_end(3:end-2))];
        end
        function scale_factor = get_piezo_scaling_factor(obj)
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:dl:pc:external-input:factor)');
            string = fscanf(obj.DLCpro_visa);
            scale_factor = str2double(string(3:end));
        end
        % returns if the system should tune the piezo with external input
        % getting the right channel and a nontrivial tuning range
        function enabled = get_external_piezo_enabled(obj)
            external_enabled = query(obj.DLCpro_visa, '(param-ref ''laser1:dl:pc:external-input:enabled)');
            input_factor =  query(obj.DLCpro_visa, '(param-ref ''laser1:dl:pc:external-input:factor)');
            input_channel = query(obj.DLCpro_visa, '(param-ref ''laser1:dl:pc:external-input:signal)');
            enabled = strcmp(external_enabled(3:4), '#t') && ...
                (str2double(input_factor(3:end))>0) && ...
                isempty(find([0,1,2,4]==input_channel,1));
        end

        function goto_freq_closedloop(obj, goto_freq_GHz, wavemeter_obj)
            c = 299792458;
            obj.set_wavelength_nm(c/goto_freq_GHz);

            volts_per_GHz = 10/2.1;  % going from 69V to 79V moved 2.1 GHz
            actual_freq = wavemeter_obj.get_freq_GHz();
            pause(1);
            while abs(actual_freq - goto_freq_GHz) > 0.05
                % dlambda = -c / f^2 * df
                obj.set_piezo_voltage( volts_per_GHz * c / goto_freq_GHz^2 *...
                                      (freq-wavemeter.get_freq_GHz()) ...
                                      + obj.get_piezo_actual_voltage() );
                pause(1);
                actual_freq = wavemeter_obj.get_freq_GHz();
                pause(1);
            end
            
        end

        %% setters
        function set_const_power(obj)
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:ctl:power-stabilization:enabled #t)');
        end
        function set_const_current(obj)
            fprintf(obj.DLCpro_visa, '(param-ref ''laser1:ctl:power-stabilization:enabled #f)');
        end
        function configure_scan_range_nm(obj, min_wavelength, max_wavelength, speed, loop_sweep)
            set_n_confirm(obj, ['(param-set! ''laser1:ctl:scan:wavelength-begin' num2str(min_wavelength, '%08.3f') ')']);
            set_n_confirm(obj, ['(param-set! ''laser1:ctl:scan:wavelength-end' num2str(max_wavelength, '%08.3f') ')']);
            set_n_confirm(obj, ['(param-set! ''laser1:ctl:scan:speed' num2str(speed, '%08.3f') ')']);
            set_n_confirm(obj, ['(param-set! ''laser1:ctl:scan:continuous-mode' obj.bool_str{1+loop_sweep} ')']);
            set_n_confirm(obj, '(param-set! ''laser1:ctl:scan:microsteps #t)');
        end
        function set_power_mW(obj,power)
            set_n_confirm(obj, ['(param-set! ''laser1:ctl:power-stabilization:setpoint ' num2str(power, '%05.2f') ')']);
        end
        function set_current_mA(obj, current)
            set_n_confirm(obj, ['(param-set! ''laser1:dl:cc:current-set ' num2str(current, '%04.1f') ')' ]);
        end
        function set_wavelength_nm(obj, wavelength)
            % could actually read limits from the laser, 
            % but I hardcoded it because I'm lazy
            if wavelength <1460 || wavelength>1570
                error('wavelength out of range')
            else
                set_n_confirm(obj, ['(param-set! ''laser1:ctl:wavelength-set ' num2str(wavelength) ')']);
            end
        end
        function set_piezo_enable(obj, true_for_on)
            set_n_confirm(obj, ['(param-set! ''laser1:dl:pc:enabled ' obj.bool_str{1+true_for_on} ')']);
        end
        function set_piezo_voltage(obj, voltage)
            set_n_confirm(obj, ['(param-set! ''laser1:dl:pc:voltage-set ' num2str(voltage) ')']);
        end
        function set_piezo_dithering(obj, true_for_on)
            set_n_confirm(obj, ['(param-set! ''laser1:dl:pc:voltage-set-dithering ' obj.bool_str{1+true_for_on} ')']);
        end
        function set_piezo_external_channel(obj, front_channel_num)
            set_n_confirm(obj, ['(param-set! ''laser1:dl:pc:external-input:signal ' num2str(front_channel_num) ')']);
        end
        function set_piezo_scaling_factor(obj, scaling_factor)
            set_n_confirm(obj, ['(param-set! ''laser1:dl:pc:external-input:factor ' num2str(scaling_factor) ')']);
        end
        function set_piezo_external_control(obj, enable)
            set_n_confirm(obj, ['(param-set! ''laser1:dl:pc:external-input:enabled ' obj.bool_str{1+enable} ')']);
        end
        
        function set_n_confirm(obj,command_string)
            value = query(obj.DLCpro_visa, command_string);
            if(value ~= '0')
                error(['something didn''t set correctly.  instead got value: ' value])
            end
        end

    end
end
