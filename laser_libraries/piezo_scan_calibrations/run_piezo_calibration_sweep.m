% run_piezo_calibration_sweep
% 
% steps the piezo voltage around a given center wavelength, and measures
% the actual wavelength
% 
% 


center_wavelength = 1536;
%% control values
% Tunics
   % coarse
disp(center_wavelength)
piezo_voltage_min    = 0;   % in nm, sweep start
piezo_voltage_max    = 140;    % in nm, sweep end
piezo_voltage_step   = 2;         % in nm, space between steps


laser_current_mA        = 70;     % laser current
calibration_description = 'YSO_Er_cav'; % description of measurement for external folder
wavemeter_is_open       = true;          Keep_wavemeter_open    = true;
laser_is_open           = true;          Keep_laser_open        = true;


%% compute values
num_steps = (piezo_voltage_max - piezo_voltage_min)/piezo_voltage_step;


%% initialize devices
if ~wavemeter_is_open
    wavemeter_instance = Burleigh_wavemeter_obj('GPIB0::4::0::INSTR');
end
if ~laser_is_open
%     laser_instance = Tunics_TECL_obj('GPIB0::2::0::INSTR',TECL_pause);
%     laser_instance.lase();
    laser_instance = Toptica_DLCpro_obj('COM5',0);
end
laser_instance.set_wavelength_nm(center_wavelength);
% laser_instance.set_current_mA(laser_current_mA);


%% take data
% initiate laser sweep and data recording
piezo_voltages = piezo_voltage_min:piezo_voltage_step:piezo_voltage_max;
wavelengths = zeros(size(piezo_voltages));
cleaned_data = zeros(size(wavelengths));
pause(10);

% run sweep
for piezo_index = 1:length(piezo_voltages)
    voltage = piezo_voltages(piezo_index);
    laser_instance.set_piezo_voltage(voltage);

    wavelengths(piezo_index) = wavemeter_instance.get_wavelength_nm();
    
end

figure()
plot(piezo_voltages, wavelengths)


laser_libraries_dir = 'C:\Users\u2\Documents\MATLAB\Er_automation\laser_libraries';
save([laser_libraries_dir filesep calibration_description  '_voltages_' num2str(center_wavelength) '.mat'],'piezo_voltages')
save([laser_libraries_dir filesep calibration_description  '_wavelengths' num2str(center_wavelength) '.mat'],'wavelengths')



%% clean up
if ~Keep_wavemeter_open
    wavemeter_instance.close();				% Close LightField
end
if ~Keep_laser_open
    laser_instance.close();
end
