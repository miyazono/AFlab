% enumeration classes for the exposure trigger response
% compatible with LightField_obj.m  v1.1

classdef LightField_trigger_enum < int32
    enumeration
        % for use with set_trigger_response
        % NoTriggerResponse 1 does not respond to triggering  
        % ReadoutPerTrigger 2 reads out the sensor after each trigger  
        % ShiftPerTrigger 3 moves to the next frame on the sensor  
        % ExposeDuringTrigger 4 controls when exposure begins and ends  
        % StartOnSingleTrigger 5 begins the experiment after the trigger 
        NoTriggerResponse    (1)
        ReadoutPerTrigger    (2)
        ShiftPerTrigger      (3)
        ExposeDuringTrigger  (4)
        StartOnSingleTrigger (5)
        % for use with set_trigger_edge
        % PositivePolarity 1 acknowledges the first trigger on a rising edge and additional triggers on a high  
        % NegativePolarity 2 acknowledges the first trigger on a falling edge and additional triggers on a low level  
        % RisingEdge 3 acknowledges all triggers on a rising edge  
        % FallingEdge 4 acknowledges all triggers on a falling edge  
        PositivePolarity    (1)
        NegativePolarity    (2)
        RisingEdge          (3) 
        FallingEdge         (4)
    end
end