classdef agilent33250a_class_new < handle
% to do:
% - update to use the pulses class
% - make sure it plots.
% - include a 
    properties
        id %GPIB identifier
        num
        pulses
        lo = 0;
        amp = 1;
        off = 0;
        freq % sampling frequency.
        ncyc = 1;
        burstperiod = 1e-3; %time in seconds
        trig = 10;
        trigdelay
        trigslope = 'POS';
        trigoutslope = 'POS';
        trigsource
        datastring
        trigdata

    end
    methods
        function obj = agilent33250a_class_new
            obj.pulses = pulses_class;
            obj.pulses.setpulsetype('rectangular');
            obj.pulses.setpulseref('edge');                       
        end
%         
        function open(obj)
            obj.id = instrfind('Type', 'gpib', 'BoardIndex', 7, 'PrimaryAddress', 10, 'Tag', '');

            % Create the GPIB object if it does not exist; otherwise use the object that was found.
            if isempty(obj.id)
              obj.id = gpib('AGILENT', 7, 10);
            else
              fclose(obj.id);
              obj.id = obj.id(1);
            end;
            
            MaxOutputBufferSize = 2^20;
            obj.id.OutputBufferSize = MaxOutputBufferSize;
            obj.id.Timeout =  25;
            obj.id.UserData = 'arb1';  
            fopen(obj.id);
            obj.output('off')
            send(obj, '*CLS');
            send(obj, '*RST');
            send(obj, '*OPC');
            send(obj, '*ESE 61');
            %obj.output('off')
        end
        function close(obj)
            fclose(obj.id);
        end
        function send(obj,string)
            GPIBSend(obj.id,string);
        end
        
        
        function sendpulses(obj)
            %obj.datastring = sprintf(',%6.4f ',obj.ydata);
            
            % need to normalize ydata between -2047 and 2047. assumes ydata is
            % already between 0 and 1 (as it should be coming from the
            % pulse class)
            
            %obj.ydata = (obj.ydata-min(obj.ydata))/(max(obj.ydata)-min(obj.ydata));
            
            range = 2047;
            obj.pulses.normydata = (obj.pulses.ydata*range);
            obj.freq = 1/length(obj.pulses.ydata)/(obj.pulses.timestep*obj.pulses.timeexp);   
            
            obj.datastring = sprintf(',%d ',obj.pulses.normydata);

            if 2*length(obj.datastring) >= obj.id.OutputBufferSize
                error('Data string (%d bytes) is too big for OutputBufferSize (%d bytes)', 2*length(obj.datastring),obj.id.OutputBufferSize);  
            end;
            
            %send data (using DAC with scaled values bc it's faster)
            obj.id.timeout = 200.0;
            %send(obj,['DATA VOLATILE ' obj.datastring]);
            send(obj,['DATA:DAC VOLATILE ' obj.datastring]);
            
            obj.id.timeout = 60.0;
            %setting frequency
            send(obj, sprintf('FREQ %8.5G', obj.freq));
            
            %selecting loaded data as output. could also copy to
            %nonvolatile memory, but it's not really necessary
            send(obj, 'FUNC:USER VOLATILE')
            send(obj, 'FUNC USER');
            
            %NumberOfPoints = query(obj.id, 'DATA:ATTR:POIN?');
        end
        
        function sendburst(obj,varargin)
            switch nargin
                case 2
                    obj.burstperiod = varargin{1};
                case 3
                    obj.burstperiod = varargin{1};
                    obj.ncyc = varargin{2};
            end
                    send(obj,sprintf('BURS:MODE TRIG;NCYC %d;INT:PER %8.5G',obj.ncyc,obj.burstperiod))
                    send(obj,'BURS:STAT ON');
        end
        
        function sendvolt(obj,varargin)
            switch nargin
                case 2
                    obj.amp = varargin{1};
                case 3
                    obj.amp = varargin{1};
                    obj.offset = varargin{2};
            end
            
            send(obj,'VOLT:UNIT VPP');
            send(obj,sprintf('VOLT %8.5G',obj.amp));
            send(obj,sprintf('VOLT:OFFS %8.5G',obj.off));
        end        
        
        function sendtrig(obj,varargin)
             switch nargin
                 case 2
                    obj.trigdelay = varargin{1};
                case 3
                    obj.trigdelay = varargin{1};
                    obj.trigsource = varargin{2};
                case 4
                    obj.trigdelay = varargin{1};
                    obj.trigsource = varargin{2};
                    obj.trigslope = varargin{2};
            end
                %set polarity on rear trigger output 
                send(obj,['OUTP:TRIG:SLOP ' obj.trigslope]); 
                
                send(obj,sprintf('TRIG:SOUR %s',obj.trigsource));
                send(obj,sprintf('TRIG:SLOP %s',obj.trigslope));
                send(obj,sprintf('TRIG:DEL %8.5G',obj.trigdelay));               
                
        end
        
        function sendall(obj)
            sendpulses(obj)
            sendtrig(obj)
            sendburst(obj)
            sendvolt(obj)
        end
        
        function plot(obj,varargin)
            obj.trigdata = zeros(size(obj.pulses.tdata));
            %should also add front trigger?
            %check this...
            obj.trig  = (obj.burstperiod2 - obj.trigdelay)/obj.timeexp;
            if strcmp(obj.trigslope,'NEG')
                obj.trigdata(obj.pulses.tdata >= obj.trig) = 1;
            else
                obj.trigdata(obj.pulses.tdata <= obj.trig) = 1;
            end
            
            if ~isempty(varargin)
                if ishandle(varargin{1})
                    plot(va,argin{1}.obj.tdata,obj.ydata,obj.tdata,obj.trigdata,varargin{2:end})
                end
            else
                plot(obj.tdata,obj.ydata,obj.tdata,obj.trigdata)
            end
            
        end
        
        function plotpulsestoh(h,obj,varargin)
            obj.trigdata = zeros(size(obj.tdata));
            %should also add front trigger?
            %check this...
            if strcmp(obj.trigslope,'NEG')
                obj.trigdata(obj.tdata >= obj.trig) = 1;
            else
                obj.trigdata(obj.tdata <= obj.trig) = 1;
            end
            
            if ~isempty(varargin)
                plot(h,obj.tdata,obj.ydata,obj.tdata,obj.trigdata+0.02,varargin)
            else
                plot(h,obj.tdata,obj.ydata,obj.tdata,obj.trigdata+0.02)
   
            end
            
        end
        
        function output(obj,str)
            switch str
                case {'on','ON'}
                    send(obj, 'OUTP:TRIG ON');
                    send(obj, 'OUTP ON');
                    send(obj, 'OUTP:SYNC ON');
                case {'off','OFF'}
                    send(obj, 'OUTP:TRIG OFF');
                    send(obj, 'OUTP OFF');
                    send(obj, 'OUTP:SYNC OFF');
            end
        end

    end
        
end

