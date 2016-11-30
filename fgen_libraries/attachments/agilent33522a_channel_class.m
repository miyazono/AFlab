classdef agilent33522a_channel_class < handle
   %% class def for the agilent 33522a. _new updates to use pulse_classdef
   % and actually has the capability to load pulses.
    
    %todo:
    % make updated copy of gui using these defs
    % check out trig delay. make everything in same units (i.e. us) to avoid
    % confusion.
    % make plot of all outputs (fgen and dgen).
    % if ambitious, configure to use rest of funcgen functionality
    % use events to autoupdate?
    properties
        id %USB identifier
        num
        pulses 
        lo = 0;
        chan = 1; %channel to send commands to. 1 or 2.
        amp = 1;
        off = 0;
        freq
        ncyc = 1;
        burstperiod = 1e-3; %time in seconds
        trigdelay = 0;
        trigslope = 'POS';
        trigsource = 'EXT';
        datastring
        trigdata
    end
    
    methods
         function obj = agilent33522a_channel_class
            obj.pulses = pulses_class;
            obj.pulses.setpulsetype('rectangular');
            obj.pulses.setpulseref('edge');         
         end
%         
        function open(obj)
            obj.id = instrfind('Type', 'visa-usb', 'RsrcName', 'USB0::0x0957::0x2307::my50002350::0::INSTR', 'Tag', '');

            % Create the GPIB object if it does not exist; otherwise use the object that was found.
            if isempty(obj.id)
              obj.id = visa('AGILENT', 'USB0::0x0957::0x2307::my50002350::0::INSTR');
            else
              fclose(obj.id);
              obj.id = obj.id(1);
            end;
            
            obj.id.Timeout = 15; %set IO time out
            %calculate output buffer size
            buffer = 8*1e6;
            obj.id.outputbuffersize = buffer+125;
              
            fopen(obj.id);
            send(obj, '*CLS');
            send(obj, '*RST');
                        

        end
        function close(obj)
            fclose(obj.id);
        end
        function send(obj,string)
            fprintf(obj.id,string);
        end
        
        
        function sendpulses(obj)
            arb = obj.pulses.ydata;

            if isrow(arb) == 0
                arb = arb';
            end

            arb = single(arb);
            
            name = 'arb';
            sRate = 1/(obj.pulses.timestep*obj.pulses.timeexp);
            %set the waveform data to single precision
            %scale data between 1 and -1. %this should already be done.
            mx = max(abs(arb));
            arb = (1*arb)/mx;

            obj.send(sprintf('SOURce%d:DATA:VOLatile:CLEar',obj.chan)); %Clear volatile memory
            obj.send('FORM:BORD SWAP');  %configure the box to correctly accept the binary arb points
            arbBytes=num2str(length(arb) * 4); %# of bytes
            header= [sprintf('SOURce%d:DATA:ARBitrary ',obj.chan) name ', #' num2str(length(arbBytes)) arbBytes]; %create header
            %disp(header)
            binblockBytes = typecast(arb, 'uint8');  %convert datapoints to binary before sending
            fwrite(obj.id, [header binblockBytes], 'uint8'); %combine header and datapoints then send to instrument
            obj.send('*WAI');
            

            %Set desired configuration for channel 1
            obj.send([sprintf('SOURce%d:FUNCtion:ARBitrary ',obj.chan) name]); 

            obj.send([sprintf('MMEM:STOR:DATA%d ',obj.chan) '"INT:\' name '.arb"']);
 
            obj.send([sprintf('SOURce%d:FUNCtion:ARB:SRATe ',obj.chan) num2str(sRate)]);%set sample rate
            obj.send(sprintf('SOURce%d:FUNCtion ARB',obj.chan)); % turn on arb function

            %obj.send(sprintf('OUTPUT%d ON',obj.chan)); %Enable Output for channel 1
            fprintf('Arb waveform downloaded to channel %d\n',obj.chan) %print waveform has been downloaded

            %Read Error
            obj.send('SYST:ERR?');
            errorstr = fscanf (obj.id);

            % error checking
            if strncmp (errorstr, '+0,"No error"',13)
               errorcheck = 'Arbitrary waveform generated without any error\n';
               fprintf (errorcheck)
            else
               errorcheck = ['Error reported: ', errorstr];
               fprintf (errorcheck)
            end
        end
        
        function sendburst(obj,varargin)
            switch nargin
                case 2
                    obj.burstperiod = varargin{1};
                case 3
                    obj.burstperiod = varargin{1};
                    obj.ncyc = varargin{2};
            end
                    send(obj,sprintf('SOUR%d:BURS:MODE TRIG;NCYC %d;INT:PER %8.5G',obj.chan,obj.ncyc,obj.burstperiod))
                    send(obj,sprintf('SOUR%d:BURS:STAT ON',obj.chan));
        end
        
        function sendvolt(obj,varargin)
            switch nargin
                case 2
                    obj.amp = varargin{1};
                case 3
                    obj.amp = varargin{1};
                    obj.off = varargin{2};
            end
            
            send(obj,sprintf('SOURce%d:VOLT:UNIT VPP',obj.chan));
            send(obj,sprintf('SOURce%d:VOLT %8.5G',obj.chan,obj.amp));
            send(obj,sprintf('SOURce%d:VOLT:OFFS %8.5G',obj.chan,obj.off));
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
                send(obj,sprintf('TRIG%d:SOUR %s',obj.chan,obj.trigsource));
                send(obj,sprintf('TRIG%d:SLOP %s',obj.chan,obj.trigslope));
                send(obj,sprintf('TRIG%d:DEL %8.5G',obj.chan,obj.trigdelay));
        end
        
        function sendall(obj)
            sendpulses(obj)
            sendtrig(obj)
            sendburst(obj)
            sendvolt(obj)
        end
        
        function plot(obj,varargin)
            obj.trigdata = zeros(size(obj.tdata));
            %should also add front trigger?
            %check this...
            if strcmp(obj.trigslope,'NEG')
                obj.trigdata(obj.tdata >= obj.trig) = 1;
            else
                obj.trigdata(obj.tdata <= obj.trig) = 1;
            end
            
            if ~isempty(varargin)
                plot(obj.tdata,obj.ydata,obj.tdata,obj.trigdata,varargin)
            else
                plot(obj.tdata,obj.ydata,obj.tdata,obj.trigdata)
                ylim([-1,2])
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
                    %send(obj, 'OUTP:TRIG ON');
                    send(obj, sprintf('OUTP%d ON',obj.chan));
                    %send(obj, 'OUTP:SYNC ON');
                case {'off','OFF'}
                    send(obj, sprintf('OUTP%d OFF',obj.chan));
                    %send(obj, 'OUTP OFF');
                    %send(obj, 'OUTP:SYNC OFF');
            end
        end

    end
        
end

