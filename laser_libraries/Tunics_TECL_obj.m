% built starting from lfm.m and the instrument control toolbox
% 
% more information on commands used in 
% http://www.equipland.com/objects/catalog/product/extras/1520_Photonetics_Tunics_PR_PRI_Manual.pdf
% 
% ETM 20150407

% frequency commands not completely implemented (because I don't think I'll use them)

classdef (ConstructOnLoad = true) Tunics_TECL_obj < handle
    properties (SetAccess = private)
        Tunics_visa;
        pause_time=0.5; % pause time after sending commands
    end
    methods
        function obj = Tunics_TECL_obj(address, time_to_pause)
            if nargin == 1
                if ~ischar(address)
                    address = 'GPIB1::2::0::INSTR';
                    disp([ 'invalid address, using ' address ])
                end
            end
            instruments = instrfind('Type', 'visa-gpib', 'RsrcName', address, 'Tag', '');

            if isempty(instruments) % Create the VISA-GPIB object if it does not exist
                obj.Tunics_visa = visa('AGILENT', address);
            else            % otherwise use the object that was found.
                fclose(instruments);
                obj.Tunics_visa = instruments(1);
            end

            fopen(obj.Tunics_visa);     % Connect to instrument object, obj.
            
            obj.pause_time = max(0.5,time_to_pause);
        end
        function lase(obj)
            fprintf(obj.Tunics_visa, 'ENABLE');
            pause(obj.pause_time);
        end
        function lasing_off(obj)
            fprintf(obj.Tunics_visa, 'DISABLE');
            pause(obj.pause_time);
        end
    	function close(obj)
            fclose(obj.Tunics_visa);    % Disconnect all objects.
        end
%       function start_sweep(obj)  Doesn't work on this laser for some reason
%           fprintf(obj.Tunics_visa, 'SCAN');
%       end
        function stop_sweep(obj)
            fprintf(obj.Tunics_visa, 'STOP');
        end
        %% getters
        function data = get_current_mA(obj)
            query(obj.Tunics_visa, 'I?');
            data = fscanf(obj.Tunics_visa);
        end
        function data = get_power_mW(obj)
            query(obj.Tunics_visa, 'P?');
            data = fscanf(obj.Tunics_visa);
        end
        function data = get_wavelength_nm(obj)
            query(obj.Tunics_visa, 'L?');
            data = fscanf(obj.Tunics_visa);
        end
        function data = get_freq_GHz(obj)
            query(obj.Tunics_visa, 'f?');
            data = fscanf(obj.Tunics_visa);
        end
        function data = is_at_limit(obj)
            query(obj.Tunics_visa, 'LIMIT?');
            data = fscanf(obj.Tunics_visa);
        end
        %% setters
        function set_const_power(obj)
            fprintf(obj.Tunics_visa, 'APCON');
            pause(obj.pause_time);
        end
        function set_const_current(obj)
            fprintf(obj.Tunics_visa, 'APCOFF');
            pause(obj.pause_time);
        end
        function set_fine_scan(obj, delta_lambda)
            fprintf(obj.Tunics_visa, ['FSCL=' num2str(delta_lambda, '%03.1f')]);
        end
%       Useless: SCAN doesn't work on this laser for some reason
        function configure_scan_range_nm(obj, min_wavelength, delta_lambda, max_wavelength)
            fprintf(obj.Tunics_visa, ['Smin=' num2str(min_wavelength, '%08.3f')]);
            fprintf(obj.Tunics_visa, ['Smax=' num2str(delta_lambda, '%08.3f')]);
            fprintf(obj.Tunics_visa, ['Step=' num2str(max_wavelength, '%04.3f')]);
        end
%       Useless: SCAN doesn't work on this laser for some reason
        function set_scan_dwell_sec(obj, dwell_time)
            fprintf(obj.Tunics_visa, ['Stime=' num2str(dwell_time, '%03.1f')]);
        end
        function set_power_mW(obj,power)
            fprintf(obj.Tunics_visa, ['P=' num2str(power, '%05.2f')]);
            pause(obj.pause_time);
        end
        function set_current_mA(obj, current)
            fprintf(obj.Tunics_visa, ['I=' num2str(current, '%04.1f')]);
        end
        function set_wavelength_nm(obj, wavelength)
            if wavelength <1450 || wavelength>1590
                error('wavelength out of range')
            else
                fprintf(obj.Tunics_visa, ['L=' num2str(wavelength, '%08.3f')]);
            end
            pause(obj.pause_time);
        end
        function set_frequency_GHz(obj, frequency)
            fprintf(obj.Tunics_visa, ['I=' num2str(frequency, '%08.1f')]);
        end
    end
end
