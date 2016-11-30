classdef pulses_class < handle
    %class to generate vectors/data to send pulses to the arbitrary
    %waveform generators
      
    properties 
        pulsetype = 'rectangular'; %'rectangular' or 'gaussian' pulses
        pulseref = 'edge'; % 'center' or 'edge'
        %when using rectangular pulses, whether to reference from the 
        %center of the previous pulse (as done with gaussian pulses) or the
        %edge]        
        
        widths = 1;
        delays = 1;
        heights = 1; %normalized height between 0 and 1.
        
        totaltime = 10; %total time
        timestep = 0.01;
        timeexp = 1E-6; %use to get absolute time i.e. timeexp = 1e-6, time is in us.
        
        cutoff = 0.05
        normydata % in case i need to store the normalized data.
    end
    
    properties (SetAccess = 'private')
        tdata %time vector with time steps (to make things easier to plot)
        ydata %vector containing heights of arb wave 
    end
    
    
    methods
        function obj = pulses_class(varargin)
              switch nargin
                case 0
                    createpulses(obj);                  
                case 1
                    createpulses(obj,varargin{1});
                case 2
                    createpulses(obj,varargin{1},varargin{2})
                case 3
                    createpulses(obj,varargin{1},varargin{2},varargin{3})                   
              end
        end
        
        function setpulsetype(obj,val)
            obj.pulsetype = val;
            createpulses(obj)            
        end
        
        function setpulseref(obj,val)
            obj.pulseref = val;
            createpulses(obj)
        end   
        
        function setwidths(obj,val)
            obj.widths = val;
            createpulses(obj)
        end
        
        function setdelays(obj,val)
            obj.delays = val;
            createpulses(obj)
        end
        
        function setheights(obj,val)
            obj.widths = val;
            createpulses(obj)
        end
        
        function createpulses(obj,varargin)
            switch nargin
                case 2
                    obj.widths = varargin{1};
                case 3
                    obj.widths = varargin{1};
                    obj.delays = varargin{2};
                case 4
                    obj.widths = varargin{1};
                    obj.delays = varargin{2};
                    obj.heights = varargin{3};
            end
            
            if length(obj.widths)<length(obj.delays)
                warning('oops. you need the same number of widths and delays. widths vector padded with ones');
                obj.widths = [obj.widths ones(1,length(obj.delays)-length(obj.widths))];
            elseif length(obj.widths)>length(obj.delays)
                warning('oops. you need the same number of widths and delays. delays vector padded with ones');
                obj.delays = [obj.delays ones(1,length(obj.widths)-length(obj.delays))];
            end
            
            npulses = length(obj.widths);
            
            if isempty(obj.heights)
                obj.heights  = ones(size(obj.widths));
            elseif length(obj.heights) < npulses
                obj.heights = [obj.heights ones(1,npulses- length(obj.heights))];
                warning('oops. heights vector padded with ones')
            elseif length(obj.heights) > npulses
                obj.heights = obj.heights(1:npulses);
                warning('oops. heights vector truncated')
            end            


            %create pulses depending on pulse type
            switch obj.pulsetype
                case {'Rect','rect','RECT','rectangular'}
                    
                    if sum(obj.delays)+sum(obj.widths)>=obj.totaltime
                        obj.totaltime = sum(obj.delays)+sum(obj.widths)+2;
                    end
                    
                    obj.tdata = 0:obj.timestep:(obj.totaltime-obj.timestep);
                    obj.ydata = zeros(size(obj.tdata));
                    
                    startstop = zeros(npulses,2);

                    if strcmp(obj.pulseref,'edge')
                        startstop(1,1) = obj.delays(1);
                        startstop(1,2) = startstop(1,1) + obj.widths(1);
                        if npulses>1
                            for pno = 2:npulses
                                startstop(pno,1) = startstop(pno-1,2)+obj.delays(pno);
                                startstop(pno,2) = startstop(pno,1)+obj.widths(pno);
                            end
                        end
                    elseif strcmp(obj.pulseref,'center')
                        for pno = 1:npulses
                            startstop(pno,1) = sum(obj.delays(1:pno))-obj.widths(pno)/2;
                            startstop(pno,2) = startstop(pno,1)+obj.widths(pno);
                        end
                    else
                        warning('oops, your pulse reference does not make sense! Check your syntax and try again.');
                    end
                    
                    for pn=1:npulses
                        obj.ydata(startstop(pn,1) <= obj.tdata & obj.tdata < startstop(pn,2)) = obj.heights(pn);
                    end
                    %assignin('base','startstop',startstop)
                    
                case {'Gauss','Gaussian','gauss','gaussian'}          
                    if sum(obj.delays)>=obj.totaltime
                        obj.totaltime = sum(obj.delays)+2;
                    end
                    
                    obj.tdata = 0:obj.timestep:(obj.totaltime-obj.timestep);
                    obj.ydata = zeros(size(obj.tdata));
                    
                    gmult = 1/(2*sqrt(2*log(2))); %to convert width to FWHM of gaussian
                    for pn=1:npulses
                        obj.ydata = obj.ydata + obj.heights(pn)*exp(-(obj.tdata-sum(obj.delays(1:pn))).^2/(2*(gmult*obj.widths(pn))^2));
                    end
                    obj.ydata(obj.ydata<=obj.cutoff) = 0;
                    
               case {'afc','AFC','comb'} % probably want both a gaussian and rectangular comb.
                    if sum(obj.delays)>=obj.totaltime
                        obj.totaltime = sum(obj.delays)+2;
                    end
                    
                    obj.tdata = 0:obj.timestep:(obj.totaltime-obj.timestep);
                    obj.ydata = zeros(size(obj.tdata));
                    
                    startstop = zeros(npulses,2);
                    for pno = 1:npulses
                        startstop(pno,1) = sum(obj.delays(1:pno))-obj.widths(pno)/2;
                        startstop(pno,2) = startstop(pno,1)+obj.widths(pno);
                    end
                    
                    for pn=1:npulses
                        obj.ydata(startstop(pn,1) <= obj.tdata & obj.tdata < startstop(pn,2)) = obj.heights(pn);
                    end
                    
%                     gmult = 1/(2*sqrt(2*log(2))); %to convert width to FWHM of gaussian
%                     for pn=1:npulses
%                         obj.ydata = obj.ydata + obj.heights(pn)*exp(-(obj.tdata-sum(obj.delays(1:pn))).^2/(2*(gmult*obj.widths(pn))^2));
%                     end
                    
                    obj.ydata = 1-obj.ydata;     
                otherwise
                    warning('oops, your pulse type wasn not recognized! Check your syntax and try again.');
            end

             
            
            %renormalize if the data gets larger than 1. (e.g. from the
            %pulses overlapping)
            if max(abs(obj.ydata))>1
                obj.ydata = (obj.ydata-min(obj.ydata))/(max(obj.ydata)-min(obj.ydata)); 
            end
        end
        
        
        
        function plot(obj,varargin)
            
            if ~isempty(varargin)
                assignin('base','varargin',varargin)
                if ishandle(varargin{1})
                    plot(varargin{1},obj.tdata,obj.ydata,varargin{2:end})
                else
                    plot(obj.tdata,obj.ydata,varargin)
                end
            else
                plot(obj.tdata,obj.ydata)
                %ylim([-1,1])
            end
        end
        
        function plotpulsestoh(h,obj,varargin)            
            if ~isempty(varargin)
                plot(h,obj.tdata,obj.ydata,varargin)
            else
                plot(h,obj.tdata,obj.ydata)
            end
            
        end
        

    end
        
end

