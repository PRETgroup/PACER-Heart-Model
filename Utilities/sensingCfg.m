%% ------------------------------------------------------------------
%  You can modify the values of the fields in Sensing_cfg_MATLABStruct
%  and evaluate this cell to create/update this structure
%  in the MATLAB base workspace.
% -------------------------------------------------------------------

function Sensing_cfg= sensingCfg
Sensing_cfg = struct;
Sensing_cfg.amp_Aegm = 1;
Sensing_cfg.b_adring = 1;
Sensing_cfg.c_va = 0.05;
Sensing_cfg.amp_Vegm = 1;
Sensing_cfg.b_vdring = 1;
Sensing_cfg.e_Twave = 0.1;
Sensing_cfg.c_av = 0.1;
Sensing_cfg.AV_RC = 100;
Sensing_cfg.VA_RC = 100;
Sensing_cfg.sense_a = 0.6;
Sensing_cfg.sense_v = 2.8;
Sensing_cfg.amp_AP = 500;
Sensing_cfg.amp_VP = 500;
end

