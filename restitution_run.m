function [Results]= restitution_run(sim_model,pacing_protocol)
%% Important: Function assumes that the 'model' parameters are already loaded
% into the workspace for simulink

% Load Simulink model
curr_sys = load_system(sim_model);

% Simulation parameters
nm = 10;           % number of beats

q = length(pacing_protocol);

Results = zeros(q,4);
%Run simulations
for m = 1:q
    t = pacing_protocol(m);
    assignin('base','t',t)
    assignin('base','nm',nm)
    
    try
        % Run simulation        
        sim(curr_sys);
        Results(m,1) = t;
        Results(m,2) = evalin('base','DI');
        Results(m,3) = evalin('base','APD');
        Results(m,4) = evalin('base','ERP');
    catch ME
        % Handle the Simulink error
        disp('An error occurred in computation, setting NaN values');
        Results(m,1) = t;
        Results(m,2) = -t;
        Results(m,3) = -t;
        Results(m,4) = -t;
    end 
end

% Display results
disp('Pacing  DI  APD  ERP')
disp(Results)

Results(Results < 0) = [];
close_system(curr_sys)

%TO ADD:
% - somehow compare the CellML APD against the Model output
% - if the pacing result is NaN set it to insanely high?
end