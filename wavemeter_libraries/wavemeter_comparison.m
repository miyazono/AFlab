wavemeter_instance1 = Burleigh_WA1600_obj('GPIB1::3::0::INSTR');
wavemeter_instance2 = Burleigh_WA1600_obj('GPIB1::4::0::INSTR');

%% stability test

wait_time_sec = 10;
num_acquisitions = 2*60*60 / wait_time_sec; % 2 hours

times = 1:num_acquisitions;
stab_wavelength = zeros(2,length(times));
stab_power = stab_wavelength;

for i=1:length(times)
    disp(times(i))
    stab_wavelength(1,i) = wavemeter_instance1.get_wavelength_nm();
    stab_wavelength(2,i) = wavemeter_instance2.get_wavelength_nm();
    
    stab_power(1,i) = wavemeter_instance1.get_power_mW();
    stab_power(2,i) = wavemeter_instance2.get_power_mW();

    pause(wait_time_sec)
end

figure(1); hold on;
% plot(stab_wavelength(1,:))
% plot(stab_wavelength(2,:))
plot(stab_wavelength(1,:)-stab_wavelength(2,:))
title('wavelength stability')

figure(2); hold on;
plot(stab_power(1,:))
plot(stab_power(2,:))
title('power stability')




%% scattered wavelengths
numpoints = 750;
set_wavelengths = 1460 + (1570-1460)*rand(1,numpoints);
scat_wavelength = zeros(2,numpoints);
scat_power = scat_wavelength;

for i=1:numpoints
    disp(set_wavelengths(i))
    laser_instance.set_wavelength_nm(set_wavelengths(i))
    pause(wait_time_sec)
    
    scat_wavelength(1,i) = wavemeter_instance1.get_wavelength_nm();
    scat_wavelength(2,i) = wavemeter_instance2.get_wavelength_nm();
    
    scat_power(1,i) = wavemeter_instance1.get_power_mW();
    scat_power(2,i) = wavemeter_instance2.get_power_mW();

end

figure(3); hold on;
% plot(scat_wavelength(1,:))
% plot(scat_wavelength(2,:))
% plot(set_wavelengths,'x')
% plot(scat_wavelength(1,:),scat_wavelength(2,:),'.',set_wavelengths,set_wavelengths,'.')
plot(set_wavelengths,scat_wavelength(1,:)-scat_wavelength(2,:),'.')
plot(set_wavelengths,set_wavelengths-scat_wavelength(2,:),'.')
plot(set_wavelengths,set_wavelengths-scat_wavelength(1,:),'.')

title('scattered wavelengths')

figure(4); hold on;
plot(scat_power(1,:))
plot(scat_power(2,:))
title('scattered power')

%%

wavemeter_instance1.close();
wavemeter_instance2.close();