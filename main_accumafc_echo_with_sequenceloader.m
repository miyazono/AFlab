tic;
initialize_instruments = false;   close_instrument_connections = false;
if initialize_instruments
    Awg_instance = Tektronix_AWG5014('169.254.22.43', 1064); %#ok<UNRCH>
    laser_instance = Toptica_DLCpro_obj('131.215.48.211');
    scope_instance = Tektronix_TDS2014B(1);
    
    clear sequence
    clear sequence_loader
    sequence_loader = Sequence_loader(Awg_instance);
end

clear afc_echo_sequence;
afc_echo_sequence.burn_amplitudes = [1 1];
afc_echo_sequence.burn_times = [1 1] * 0.000020;
% wait time after [pulse1,pulse2,before read,between reads,after read] in ms
afc_echo_sequence.wait_times = [0.000090 0.5 10 0.1 100]; %[0.0002 0.005 10 10];
afc_echo_sequence.num_burn_loops = 10;%1000;%
afc_echo_sequence.input_rise_time = 5e-6;%0;%
afc_echo_sequence.out_rise_time = 0;
afc_echo_sequence.MEMS_rise_time = 0.1;

afc_echo_sequence.read_time = 0.000020;
afc_echo_sequence.read_amplitude = 0.5;%0.00125;%
afc_echo_sequence.num_read_loops = 10;

Awg_instance.set_marker_out_range(4,2,2,2.1)
Awg_instance.set_marker_out_range(4,2,0.1,0)
Awg_instance.set_marker_out_range(4,2,2,0)
sequence_loader.run_accumulated_afc_echo(afc_echo_sequence);
