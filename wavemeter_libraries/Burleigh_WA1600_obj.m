% built starting from lfm.m and the instrument control toolbox
% 
% If MATLAB doesn't detect the wavemeter, make sure the GPIB interface is
% enabled.
% 
% more information on commands used (and many more commands) in
% http://ultra.bu.edu/facilities/manuals/burleighWA1100.pdf
% 
% sample use:
% 	wavemeter_instance = Burleigh_wavemeter_obj('GPIB0::4::0::INSTR');
% 	wavelength = wavemeter_instance.get_wavelength_nm();
%   wavemeter_instance.close();
%
% ETM 201501021


classdef (ConstructOnLoad = true) Burleigh_WA1600_obj < handle
    properties (SetAccess = private)
        Burleigh_visa;
        power_units = 3; % 1=dBm, 2=uW, 3=mW
        wavelength_units = 1; %1=nm, 2=GHz, 3=wavenumber
        statusbyte={'operation complete','','query error',...
            'device dependent error','execution error','command error','','power on'};
    end
    methods
        function obj = Burleigh_wavemeter_obj(address)
            if nargin == 1
                if ~ischar(address)
                    address = 'GPIB0::4::0::INSTR';
                    disp([ 'invalid address, using ' address ])
                end
            end
            instruments = instrfind('Type', 'visa-gpib', 'RsrcName', address, 'Tag', '');

            if isempty(instruments) % Create the VISA-GPIB object if it does not exist
                obj.Burleigh_visa = visa('Agilent', address);
            else            % otherwise use the object that was found.
                fclose(instruments);
                obj.Burleigh_visa = instruments(1);
            end

            fopen(obj.Burleigh_visa);     % Connect to instrument object, obj.
            
            % set power mode to mW and wavelength to nm
            fprintf(obj.Burleigh_visa, 'DISP:UNIT:POW MILL');
            fprintf(obj.Burleigh_visa, 'DISP:UNIT:WAV NM');
            
        end
        
        function reset(obj)
            fprintf(obj.Burleigh_visa, '*RST');
        end
        function close(obj)
            fclose(obj.Burleigh_visa);    % Disconnect all objects.
        end
        %% getters
%         function data = get_status(obj)
%             output = query(obj.Burleigh_visa, '*ESR?');
%             data = obj.statusbyte(logical(de2bi(output,8)));
%         end
        
        function data = get_power_mW(obj)
            if obj.power_units ~= 3
                fprintf(obj.Burleigh_visa, 'DISP:UNIT:POW MILL');
                obj.power_units=3;
            end
            data = str2double(query(obj.Burleigh_visa, ':MEAS:POW?'));
        end
        function data = get_power_dBm(obj)
            if obj.power_units ~= 1
                fprintf(obj.Burleigh_visa, 'DISP:UNIT:POW DBM');
                obj.power_units=1;
            end
            data = str2double(query(obj.Burleigh_visa, ':MEAS:POW?'));
        end
        function data = get_wavelength_nm(obj)
            if obj.power_units ~= 1
                fprintf(obj.Burleigh_visa, 'DISP:UNIT:WAV NM');
                obj.power_units=1;
            end
            data = str2double(query(obj.Burleigh_visa, ':MEAS:WAV?'));
        end
        function data = get_freq_GHz(obj)
            if obj.power_units ~= 2
                fprintf(obj.Burleigh_visa, 'DISP:UNIT:WAV GHZ');
                obj.power_units=2;
            end
            data = str2double(query(obj.Burleigh_visa, ':MEAS:FREQ?'));
        end
        function data = get_freq_wavenum(obj)
            if obj.power_units ~= 3
                fprintf(obj.Burleigh_visa, 'DISP:UNIT:WAV WNUM');
                obj.power_units=3;
            end
            data = str2double(query(obj.Burleigh_visa, ':MEAS:WNUM?'));
        end
    end
end
