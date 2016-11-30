classdef (ConstructOnLoad = true) TimeHarp_260nano < handle
    %TIMEHARP260NANO
    %   matlab interface for the TimeHarp 260 nano.
    %   based on Chuting's Timeharp_CWODMR_spc.m
    %
    %   usage:
    %     timeharp = TimeHarp_260nano(0);
    %     timeharp.configure_hist(200,20,4000);
    %     timeharp.start_acq(5000);
    %     timeharp.stop_acq();
    %     timeharp.start_acq(10000);
    %     timeharp.pause_til_done();
    %     [x,t] = timeharp.get_counts();
    %     figure(); plot(t,x)
    %     timeharp.close();
    % 
    % Dependencies:
    % Timeharp
    % geterrorstring.m  (in timeharp library)
    % closedev.m        (in timeharp library)
    % th260lib64.lib
    properties (SetAccess = private)
        timeharp_number
        verbose
        MAX_HIST_TIMEBINS
    end
    
    methods
        function obj = TimeHarp_260nano(verbose)
            obj.verbose = verbose;
            if (~libisloaded('TH260lib'))
                % Attention: The header file name given below is case 
                % sensitive and must be spelled exactly the same as the 
                % actual name on disk except the file extension. 
                % Wrong case will apparently do the load successfully but 
                % you will not be able to access the library!
                % The alias is used to provide a fixed spelling for any
                % further access via calllib() etc, which is also case 
                % sensitive.
                loadlibrary('th260lib64.dll', 'th260lib.h', 'alias', 'TH260lib');
            end;

            if (libisloaded('TH260lib'))
                if obj.verbose
                    fprintf('TH260lib opened successfully\n');
                end
                %libfunctionsview('TH260lib'); %use this to test for proper loading
            else
                error('Could not open TH260lib');
            end;

            Serial = blanks(8); % (enough length)
            Serial = calllib('TH260lib', 'TH260_OpenDevice', 0, libpointer('cstring', Serial));
            if verbose
                fprintf('\n  %1d \t\t S/N %s\n', 0, Serial);
            end
            obj.timeharp_number = 0; %keep index to device we may want to use
            
            obj.MAX_HIST_TIMEBINS = 32768;
        end

        function configure_hist(obj, SyncTriggerLevel_mV, ...
                                InputTriggerLevel_mV, binsize_ns)
            %Initialize the device to histogram mode
            obj.send_set_command_from_lib({'TH260_Initialize', 0}); 
            %Set sync settings
            obj.send_set_command_from_lib({'TH260_SetSyncEdgeTrg', SyncTriggerLevel_mV, 0});
            %Set input settings
            obj.send_set_command_from_lib({'TH260_SetInputEdgeTrg', 0, InputTriggerLevel_mV, 1});
            %Set bin size in ns (round down to nearest possible)
            if binsize_ns<1
                error('binsize must be at least 1 ns')
            else
                obj.send_set_command_from_lib({'TH260_SetBinning', floor(log(binsize_ns)/log(2))});
            end
            % if you want to get creative, you should fetch the binsize
            % instead of assuming that it's 2
            %   resolution = double(0);
            %   resolution_ptr = libpointer('doublePtr',resolution);
            %   binsteps = int32(0);
            %   binsteps_ptr = libpointer('int32Ptr', binsteps);
            %   resolution = obj.send_get_command_from_lib({'TH260_GetBaseResolution', resolution_ptr, binsteps_ptr});
            % 	resolution_vec = resolution * (1:length(counts_buffer(1,:)));
        end

        % args = [command_str, value, channel_num, other arguments]
        % 'TH260lib' comes first and the timeharp number comes third
        function send_set_command_from_lib(obj, args)
            switch length(args)
                case 1
                    outcome = calllib('TH260lib', args{1}, obj.timeharp_number);
                case 2
                    outcome = calllib('TH260lib', args{1}, obj.timeharp_number, args{2});
                case 3
                    outcome = calllib('TH260lib', args{1}, obj.timeharp_number, args{2}, args{3});
                case 4
                    outcome = calllib('TH260lib', args{1}, obj.timeharp_number, args{2}, args{3}, args{4});
                otherwise
                   error(['incorrect number of arguments for command' args{1}])
            end
            if (outcome<0)
                closedev;
                error('\n %s error %s. Aborted.\n', args{1}, geterrorstring(outcome));
            end;
        end
        function output = send_get_command_from_lib(obj, args)
            outcome = 0;
            switch length(args)
                case 2
                    [outcome, output] = calllib('TH260lib', args{1}, obj.timeharp_number, args{2});
                case 3
                    [outcome, output] = calllib('TH260lib', args{1}, obj.timeharp_number, args{2}, args{3});
                case 4
                    [outcome, output] = calllib('TH260lib', args{1}, obj.timeharp_number, args{2}, args{3}, args{4});
                otherwise
                    disp('incorrect number of arguments to send_get_command_from_lib')
            end
            if (outcome<0)
                closedev;
                error('\n %s error %s. Aborted.\n', args{1}, geterrorstring(outcome));
            end;
        end
        function start_acq(obj, Acqtime_ms)
            obj.send_set_command_from_lib({'TH260_ClearHistMem'});
            obj.send_set_command_from_lib({'TH260_StartMeas', Acqtime_ms});
        end
        function stop_acq(obj)
            obj.send_set_command_from_lib({'TH260_StopMeas'});
        end
        function pause_til_done(obj)
            ctcdonePtr = libpointer('int32Ptr', int32(0));
            ctcdone = int32(0);
            while (ctcdone==0)
                [~, ctcdone] = calllib('TH260lib', 'TH260_CTCStatus', obj.timeharp_number, ctcdonePtr);
            end;
        end
        function [counts_buffer, resolution_vec] = get_counts(obj)
            counts_buffer  = uint32(zeros(1,obj.MAX_HIST_TIMEBINS));
            buffer_ptr = libpointer('uint32Ptr', counts_buffer(1,:));
            counts_buffer(1,:) = obj.send_get_command_from_lib({'TH260_GetHistogram', buffer_ptr, 0, 0});
            resolution = double(0);
            resolution_ptr = libpointer('doublePtr', resolution);
            resolution = obj.send_get_command_from_lib({'TH260_GetResolution', resolution_ptr});
            resolution_vec = resolution * (1:length(counts_buffer(1,:))) * 1e-9;
        end
        function close(obj)
            obj.stop_acq();
            unloadlibrary TH260lib
        end
    end
end
