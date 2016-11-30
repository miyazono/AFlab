% read 10%-90% rise time measurements from the oscilloscope

risetime = zeros(25,1);

for index = 1:length(risetime)
    
    [x,y] = scope_instance.get_waveform(2);

    pause(1)
    
    tenpercent = (max(y) - min(y))*.1+min(y);
    ninetypercent = (max(y) - min(y))*.9+min(y);
    t10 = find(y>tenpercent,1);
    t90 = find(y>ninetypercent,1);
    risetime(index) = x(t90) - x(t10);

end

disp(risetime*1e9);