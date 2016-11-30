classdef srsfgen < handle
    %basically a copy of the agilentfgen functions to send to the srs
    %function generator... I could put this into a general fgen class, but
    %I don't want to spend too much time on it now.
    %currently only really setup to put in pulses for the photon echo
    %experiment. It would be easy enough to expand this for complete
    %control over all the features of the function generator
    %updated 10/21 to include support for gaussian pulses
    
    properties
        id %GPIB identifier
        num
        pulsess %stores start/stop of each pulse
        pulseh %stores height of each pulse
        lo = 0;
        tt = 10;%total time
        tdata %time vector with time steps (to make things easier to plot)
        ydata %vector containing heights of arb wave
        normydata
        pulsetype = 'Rect';
        ts = 0.1; %size of minimum step. 
        timeexp = 1E-6;%use to get absolute time
        amp = 1;
        offset = 0;
        freq %sampling frequency for arbitrary waveforms
        ncyc = 1;
        burstperiod = 1e-3; %time in seconds
        trig = 10;
        trigslope = 'POS';
        datastring
        trigdata

    end
    methods
%         function obj = agilentfgen
%                       
%         end
%         
        function open(obj)
            obj.id = instrfind('Type', 'visa-gpib', 'RsrcName', 'GPIB0::4::0::INSTR', 'Tag', '');

            % Create the GPIB object if it does not exist; otherwise use the object that was found.
            if isempty(obj.id)
              obj.id = visa('AGILENT', 'GPIB0::19::0::INSTR');
            else
              fclose(obj.id);
              obj.id = obj.id(1);
            end;
            
            MaxOutputBufferSize = 2^14;
            obj.id.OutputBufferSize = MaxOutputBufferSize;
            obj.id.Timeout =  25;
            fopen(obj.id);
%             send(obj, '*CLS');
%             send(obj, '*RST');
%             send(obj, '*OPC');
%             send(obj, '*ESE 61');
        end
        function close(obj)
            fclose(obj.id);
        end
        function send(obj,string)
            fprintf(obj.id,string);
        end
          
        function createpulses(obj,varargin)
            % pulsess = [1 2;2 3;3 4;5 6]; %each row specifies start/stop of pulses
            % pulseh = [.2; .5; 1]; %height of each pulse in pulsess. if all are not specified, 
            % %will default to first value. If empty, will default to 1.
            switch nargin
                case 2
                    obj.pulsess = varargin{1};
                case 3
                    obj.pulsess = varargin{1};
                    obj.pulseh = varargin{2};
            end
            if obj.pulsess(end)>=obj.tt
                obj.tt = obj.pulsess(end)+1;
            end
            %could use this to set resolution to minimum pulse width. 
            %obj.ts = min(abs(obj.pulsess(:,2)-obj.pulsess(:,1)));
            obj.tdata = 0:obj.ts:(obj.tt-obj.ts);
             
            obj.ydata = zeros(size(obj.tdata))+obj.lo;
            npulses = size(obj.pulsess,1);
            for pn=1:npulses
                if isempty(obj.pulseh)
                    hi = 1;
                elseif length(obj.pulseh) == npulses
                    hi = obj.pulseh(pn);
                else
                    hi = obj.pulseh(1);
                end
                obj.ydata(obj.pulsess(pn,1) <= obj.tdata & obj.tdata < obj.pulsess(pn,2)) = hi;
            end
            %normalize ydata between -2047 and 2047. assumes ydata is
            %already between 0 and 1, but I should add error checking...
            range = 2047;
            obj.normydata = floor(obj.ydata*range); %need to round so the checksum doesn't get messed up.
            %obj.freq = 1/(obj.ts*obj.timeexp);
            obj.freq = 1/length(obj.ydata)/(obj.ts*obj.timeexp);
        end
        
        
        function creategaussianpulses(obj,varargin)
            % pulsess = [1 2;2 3;3 4;5 6]; %each row specifies start/stop of pulses
            % pulseh = [.2; .5; 1]; %height of each pulse in pulsess. if all are not specified, 
            % %will default to first value. If empty, will default to 1.
            switch nargin
                case 2
                    obj.pulsess = varargin{1};
                case 3
                    obj.pulsess = varargin{1};
                    obj.pulseh = varargin{2};
            end
            if obj.pulsess(end,1)+3*obj.pulsess(end,2)>=obj.tt
                obj.tt = obj.pulsess(end,1)+3*obj.pulsess(end,2);
            end
            %could use this to set resolution to minimum pulse width. 
            %obj.ts = min(abs(obj.pulsess(:,2)-obj.pulsess(:,1)));
            obj.tdata = 0:obj.ts:(obj.tt-obj.ts);
            
            gmult = 1/(2*sqrt(2*log(2)));
             
            obj.ydata = zeros(size(obj.tdata))+obj.lo;
            npulses = size(obj.pulsess,1);
            for pn=1:npulses
                if isempty(obj.pulseh)
                    hi = 1;
                elseif length(obj.pulseh) == npulses
                    hi = obj.pulseh(pn);
                else
                    hi = obj.pulseh(1);
                end
                obj.ydata = obj.ydata + hi*exp(-(obj.tdata-obj.pulsess(pn,1)).^2/(2*(gmult*obj.pulsess(pn,2))^2));
            end
            %normalize ydata between -2047 and 2047. assumes ydata is
            %already between 0 and 1, but I should add error checking...
            range = 2047;
            obj.normydata = (obj.ydata*range);
            obj.freq = 1/length(obj.ydata)/(obj.ts*obj.timeexp);             
        end
        
        function twoppe(obj, width, delay)
            start = 1; %starting at 1 because the func gen does funny things if you start at 0.
            p1 = [start start+width];
            p2 = [p1(2)+delay p1(2)+delay+2*width];
            %if p2(2)> obj.tt
            %    obj.tt = ps(2) + 1;
            %end
            createpulses(obj,[p1;p2]);
        end
        
        function threeppe(obj, width, delay1, delay2)
            start = 1; %starting at 1 because the func gen does funny things if you start at 0.
            p1 = [start start+width];
            p2 = [p1(2)+delay1 p1(2)+delay1+width];
            p3 = [p2(2)+delay2 p2(2)+delay2+width];
            %if p3(2)> obj.tt
            %    obj.tt = ps(2) + 1;
            %end
            createpulses(obj,[p1;p2;p3]);
        end
        
        function varppe(obj,widths,delays,varargin)
            %converts widths and delays to pulse start/stops
            switch obj.pulsetype
                case {'Rect','rect','RECT','rectangular'}
                    if length(widths)==length(delays)
                        npulses = length(widths);
                        pout = zeros(npulses,2);
                        pout(1,1) = delays(1);
                        pout(1,2) = pout(1,1) + widths(1);
                        if npulses>1
                            for pno = 2:npulses
                                pout(pno,1) = pout(pno-1,2)+delays(pno);
                                pout(pno,2) = pout(pno,1)+widths(pno);
                            end
                        end
                    else
                        warning('oops. you need the same number of widths and delays');
                    end
                                %allows you to use varargin to specify the pulse heights.        
                    if ~isempty(varargin)
                        createpulses(obj,pout,varargin{1});
                    else
                        createpulses(obj,pout);
                    end
                case {'Gauss','Gaussian','gauss','gaussian'}                    
                    if length(widths)==length(delays)
                        npulses = length(widths);
                        pout = zeros(npulses,2);
                        pout(1,1) = delays(1);
                        pout(1,2) = widths(1);
                        if npulses>1
                            for pno = 2:npulses
                                pout(pno,1) = pout(pno-1,1)+delays(pno);
                                pout(pno,2) = widths(pno);
                            end
                        end
                    else
                        warning('oops. you need the same number of widths and delays');
                    end
                    
                                %allows you to use varargin to specify the pulse heights.        
                    if ~isempty(varargin)
                        creategaussianpulses(obj,pout,varargin{1});
                    else
                        creategaussianpulses(obj,pout);
                    end
            end
            

            
        end 
        
        function sendpulses(obj)
            
            if length(obj.normydata)>16300
                 obj.normydata = obj.normydata(1:16300);
                 disp('oops! you can only send up to 16300 points. input has been truncated')
            end
            %obj.datastring = sprintf(',%6.4f ',obj.ydata);
            %obj.datastring = sprintf(',%d ',obj.normydata);

            if 2*length(obj.datastring) >= obj.id.OutputBufferSize
                error('Data string (%d bytes) is too big for OutputBufferSize (%d bytes)', 2*length(obj.datastring),obj.id.OutputBufferSize);  
            end;
            
            checksum = 0;
              for i =1:length(obj.normydata)
                  checksum = checksum+obj.normydata(i);
                  %making sure the sum rolls over when it hits the maximum.
                  if checksum>32767
                      checksum = checksum-65536;
                  end
              end
            
            numpoints = length(obj.normydata);
            
            arbmode = 0; % 0 is point mode, 1 is vector format 
            arbquery = sprintf('LDWF?%g,%g',arbmode,numpoints);
            reply = query(obj.id, arbquery);
            %disp(reply)
            if strncmp(reply,'1',1)
                 fwrite(obj.id, obj.normydata,'int16');
                 fwrite(obj.id, checksum,'int16');
                 fprintf(obj.id, 'FUNC5');
                 fprintf(1,'%i points sent \n',length(obj.normydata))
            else
                disp('some sort of error occured in transmission. sorry about that')
            end
            %send data (using DAC with scaled values bc it's faster)
            %obj.id.timeout = 200.0;
            %send(obj,['DATA VOLATILE ' obj.datastring]);
            %send(obj,['DATA:DAC VOLATILE ' obj.datastring]);
            
            obj.id.timeout = 60.0;
            %setting frequency
            maxfreq = 1e7;
            if obj.freq<maxfreq
                send(obj, sprintf('FSMP %8.5G', obj.freq));
            else
                warning('oops. the maximum sampling rate is ~1e7. increase your timestep and try again!');
            end
            
            %selecting loaded data as output. could also copy to
            %nonvolatile memory, but it's not really necessary
            %send(obj, 'FUNC:USER VOLATILE')
            %send(obj, 'FUNC USER');
            
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
            send(obj,sprintf('VOLT:OFFS %8.5G',obj.offset));
        end        
        
        function sendtrig(obj,varargin)
            switch nargin
                case 2
                    obj.trig = varargin{1};
                case 3
                    obj.trig = varargin{1};
                    obj.trigslope = varargin{2};
            end
                trigdelay = obj.burstperiod/2 - obj.trig*obj.timeexp;
                send(obj,sprintf('TRIG:SOUR IMM;SLOP POS;DEL %8.5G',trigdelay));
                
                %set polarity on rear trigger output 
                send(obj,['OUTP:TRIG:SLOP ' obj.trigslope]);  
        end
        
        function sendall(obj)
            sendpulses(obj)
            sendtrig(obj)
            sendburst(obj)
            sendvolt(obj)
        end
        
        function plotpulses(obj,varargin)
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

