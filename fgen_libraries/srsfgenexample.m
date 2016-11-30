% Find a VISA-GPIB object.
srsfgen = instrfind('Type', 'visa-gpib', 'RsrcName', 'GPIB0::4::0::INSTR', 'Tag', '');

% Create the VISA-GPIB object if it does not exist
% otherwise use the object that was found.
if isempty(srsfgen)
    srsfgen = visa('AGILENT', 'GPIB0::4::0::INSTR');
else
    fclose(srsfgen);
    srsfgen = srsfgen(1);
end
%need to set buffer to a reasonable value (greater than the size of the
%maximum string I can send)
srsfgen.outputbuffersize = 2^14;

% Connect to instrument object
fopen(srsfgen);
%will want to use something like this when I create the class so I'm using
%a standard set of commands.
% function send(obj,string)
%     GPIBSend(obj.id,string);
% end

% Communicating with instrument object
% data1 = query(srsfgen, 'AMPL?');
fprintf(srsfgen, 'AMPL1.6VP');
% fprintf(srsfgen, 'AMPL?');
% data2 = fscanf(srsfgen);
% data3 = query(srsfgen, 'AMPL?');
% data4 = query(srsfgen, 'func?');
% data5 = query(srsfgen, 'FUNC?');
 fprintf(srsfgen, 'FUNC0');
% fprintf(srsfgen, 'FUNC?');
% data6 = fscanf(srsfgen);
% fprintf(srsfgen, 'OFFS?');
% data7 = fscanf(srsfgen);

%trying to send in a arbitrary waveform.
t = 0:0.01:20; 
%in point mode, can send at most 16300 points. So I'll check for that and
%then truncate if it's longer than that.
if length(t)>16300
    t = t(1:16300);
    disp('oops! you can only send up to 16300 points. input has been truncated')
end


 y = zeros(size(t)); %should be between -1 and 1.
% 
% y(10:11) = 1;
% 
 y(20:30) = 1;
% 
% %
% y(30:40) = 1;
% y(100:200) = 1;
% 
 y = y*2047;
%y = fgen.normydata;
checksum = 0;

  for i =1:length(y)
      checksum = checksum+y(i);
      %making sure the sum rolls over when it hits the maximum.
      if checksum>32767
          checksum = checksum-65536;
      end
  end


checksum = checksum;


numpoints = length(y);
arbmode = 0; % 0 is point mode, 1 is vector format 
arbquery = sprintf('LDWF?%g,%g',arbmode,numpoints);
reply = query(srsfgen, arbquery);
%disp(reply)
if strncmp(reply,'1',1)
     fwrite(srsfgen, y,'int16');
     fwrite(srsfgen, checksum,'int16');
     fprintf(srsfgen, 'FUNC5');
     fprintf(1,'%i points sent \n',length(y))
else
    disp('some sort of error occured in transmission. sorry about that')
end
%pause(2)
%end


% Disconnect from instrument object
fclose(srsfgen);
