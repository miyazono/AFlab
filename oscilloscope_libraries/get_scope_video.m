numframes = 3600;
xs = zeros(numframes,2500);
ys = zeros(numframes,2500);

for i=1:numframes
    [x,y] = scope_instance.get_waveform(2);
    xs(i,:) = x;
    ys(i,:) = y;
%     disp(['frame ' num2str(i)])
    input('press enter to capture next frame')
end

figure();
plot(xs',ys');
save('tune1_through_resonance_video_beam2jake.mat','xs','ys')
