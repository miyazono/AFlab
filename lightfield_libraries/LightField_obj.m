% LightField_obj.m  (originally lfm.m)
% 
% edited ETM 20150405
% v1.1 - fixed bug causing lightfield to crash if commands are send while exposing
%
% get(setting);                 % Gets the current value of 'setting' from LightField.
% set(setting, value);          % Sets 'setting' to value 'value'.
% load_experiment(value);       % Loads an experiment.
% set_exposure_ms(value);          % Sets the exposure time in msec.
% set_frames(value);            % Sets the number of frames.
% set_savedir(value);           % Sets the save file directory (added)
% set_savename(value);          % Sets the save file name (added)
% set_trigger_edge(value);      % Chooses + polarity, - polarity, rising edge
                                % or falling edge (added)
% set_trigger_response(value);  % no response, capture, take frame, expose
                                % during, or start experiment on trigger
%
% additional functionality added using ExperiementSettings Members listed
% in the 'LightField Experiment Settings.chm' file
% find the path to the setting you want to change by using the file
% C:\Program Files\Princeton Instruments\LightField\Automation\LightFieldCSharpAutomationSample
%    \PrincetonInstruments.LightFieldAddInSupportServices.xml


                                
classdef (ConstructOnLoad = true) LightField_obj
    properties (Access = private)
        automation;
        addinbase;
        application;
        experiment;
        pause_time = 0.5;  % time to wait between Stop and next command
    end
    methods
        function out = LightField_obj(visible)
            out.addinbase = PrincetonInstruments.LightField.AddIns.AddInBase();
            out.automation = PrincetonInstruments.LightField.Automation.Automation(visible,[]);
            out.application = out.automation.LightFieldApplication;
            out.experiment = out.application.Experiment;
        end
    	function close(obj)
            if  obj.experiment.IsRunning();
                obj.experiment.Stop();
                pause(1)
            end
			obj.automation.Dispose();
        end
        function set(obj,setting,value)             %(ETM modified)
            if obj.experiment.Exists(setting)
                if obj.experiment.IsValid(setting,value)
                if  obj.experiment.IsRunning();
                    obj.experiment.Stop();
                    pause(obj.pause_time)
                end
                    obj.experiment.SetValue(setting,value);
                end
            end
        end
        function return_value = get(obj,setting)
            if obj.experiment.Exists(setting)
                return_value = obj.experiment.GetValue(setting);
            end
        end
        function load_experiment(obj,value)
            if exist(value,'file')==2
                good_filepath = value;
            else
                [good_file, good_path, ~] = uigetfile('C:\Users\Faraon Lab\Documents\LightField\Experiments\*.lfe','Experiment file invalid, choose new one');
                good_filepath = [good_path good_file];
            end
                obj.experiment.Load(good_filepath);
        end
        function set_exposure_ms(obj,value)
            obj.set(PrincetonInstruments.LightField.AddIns.CameraSettings.ShutterTimingExposureTime,value);
        end
        function set_frames(obj,value)
            obj.set(PrincetonInstruments.LightField.AddIns.ExperimentSettings.FrameSettingsFramesToStore,value);
        end
        function set_savedir(obj,value)             %(ETM added)
            if exist(value,'file')==7
                if value(end) == filesep
                    cleaned_dir = value(1:end-1);
                else
                    cleaned_dir = value;
                end
            else
                cleaned_dir = uigetdir('C:\Users\Faraon Lab\Data\spectrometer','Error making/setting save dir.  Choose new save dir');
            end
            obj.set(PrincetonInstruments.LightField.AddIns.ExperimentSettings.FileNameGenerationDirectory,cleaned_dir);
        end
        function set_savename(obj,value)            %(ETM added)
            obj.set(PrincetonInstruments.LightField.AddIns.ExperimentSettings.FileNameGenerationBaseFileName,value);
        end
        function set_incrementname(obj,value)       %(ETM added)
            obj.set(PrincetonInstruments.LightField.AddIns.ExperimentSettings.FileNameGenerationAttachIncrement,value);
        end
        function set_add_date_to_name(obj,value)    %(ETM added)
            obj.set(PrincetonInstruments.LightField.AddIns.ExperimentSettings.FileNameGenerationAttachDate,value);
        end
        function set_trigger_edge(obj, value)       %(ETM added)
            obj.set(PrincetonInstruments.LightField.AddIns.CameraSettings.HardwareIOTriggerDetermination,int32(value));
        end 
        function set_trigger_response(obj, value)   %(ETM added)
            obj.set(PrincetonInstruments.LightField.AddIns.CameraSettings.HardwareIOTriggerResponse,int32(value));
        end
        
        
        function data = acquire(obj)
            import System.IO.FileAccess;
            if  obj.experiment.IsRunning();
                obj.experiment.Stop();
                pause(1)
            end
            obj.experiment.Acquire();
            while obj.experiment.IsRunning
            end
            lastfile = obj.application.FileManager.GetRecentlyAcquiredFileNames.GetItem(0);
			imageset = obj.application.FileManager.OpenFile(lastfile,FileAccess.Read);
            if imageset.Regions.Length == 1
                if imageset.Frames == 1
                    frame = imageset.GetFrame(0,0);
                    data = reshape(frame.GetData().double,frame.Width,frame.Height)';
                    return;
                else
                    data = [];
                    for i = 0:imageset.Frames-1
                        frame = imageset.GetFrame(0,i);
                        data = cat(3,data,reshape(frame.GetData().double,frame.Width,frame.Height)');
                    end
                    return;
                end
            else
                data = cell(imageset.Regions.Length,1);
                for j = 0:imageset.Regions.Length-1
                    if imageset.Frames == 1
                        frame = imageset.GetFrame(j,0);
                        buffer = reshape(frame.GetData().double,frame.Width,frame.Height)';
                    else
                        buffer = [];
                        for i = 0:imageset.Frames-1
                            frame = imageset.GetFrame(j,i);
                            buffer = cat(3,buffer,reshape(frame.GetData().double,frame.Width,frame.Height)');
                        end
                    end
                    data{j+1} = buffer;
                end
            end
        end
%         function cr=get_CustomRegion(obj)
%             cr=obj.experiment.CustomRegions();
%         end
%         function sr=get_SelectedRegion(obj)
%             sr=obj.experiment.SelectedRegions();
%         end
%         function fr=get_FullSensorRegion(obj) 
%             fr=obj.experiment.FullSensorRegion();
%         end
        function cr=get_CustomRegion(obj)   %(ETM added)
            cr=obj.experiment.GetCurrentRange(PrincetonInstruments.LightField.AddIns.CameraSettings.ReadoutControlRegionsOfInterestCustomRegions);
        end
        function sr=get_SelectedRegion(obj)   %(ETM added)
            sr=obj.experiment.GetCurrentRange(PrincetonInstruments.LightField.AddIns.CameraSettings.ReadoutControlRegionsOfInterestSelection);
        end        
        
    end
end