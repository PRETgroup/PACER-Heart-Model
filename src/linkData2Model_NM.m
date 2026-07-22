%% ------------------------------------------------------------------
%  Create the cfg for M type cell;
%  You can modify the values of the fields in Config_MATLABStruct
%  Assign the value of the struct to the parameter 'cfg'
%  Link the data type definition to the model
% -------------------------------------------------------------------
 modelFile='models/Node_NM_3D.slx';
% Open dictionaries and create empty, perfectly-ordered template structs
dict_ = Simulink.data.dictionary.open('NM_dd.sldd');
Config_MATLABStruct_N = Simulink.Bus.createMATLABStruct('Config_N', [], [1 1], dict_);
Config_MATLABStruct_M = Simulink.Bus.createMATLABStruct('Config_M', [], [1 1], dict_);
% 
Config_MATLABStruct_N.BCL = 0.814;
Config_MATLABStruct_N.SD = 0.002;
Config_MATLABStruct_N.f1 = 0.1;
Config_MATLABStruct_N.f2 = 0.25;
Config_MATLABStruct_N.sigma1sq = 0.0035;
Config_MATLABStruct_N.sigma2sq = 0.007;
Config_MATLABStruct_N.d2 = 1281;
Config_MATLABStruct_N.ERP = 0.1615;
Config_MATLABStruct_N.d0 = -773.2;
Config_MATLABStruct_N.MDP = -85.3;
Config_MATLABStruct_N.VT = 23.81;
Config_MATLABStruct_N.VR = 47.94;
Config_MATLABStruct_N.Vh = -4.0;
Config_MATLABStruct_N.hr = 0.1;
Config_MATLABStruct_N.hs = 35;
Config_MATLABStruct_N.s = 5;
Config_MATLABStruct_N.j = 0;
Config_MATLABStruct_N.m = 1;
Config_MATLABStruct_N.h = 0.2;
Config_MATLABStruct_N.f = 0.1;
Config_MATLABStruct_N.r = 0.5;

Config_MATLABStruct_M.ax0 = -8.7;
Config_MATLABStruct_M.ay0 = -190.9;
Config_MATLABStruct_M.az0 = -190.4;
Config_MATLABStruct_M.ax1 = -23.6;
Config_MATLABStruct_M.ay1 = -45.5;
Config_MATLABStruct_M.az1 = -12.9;
Config_MATLABStruct_M.ax2 = -6.9;
Config_MATLABStruct_M.ay2 = 75.9;
Config_MATLABStruct_M.az2 = 6826.5;
Config_MATLABStruct_M.ax3 = -17.809705;
Config_MATLABStruct_M.ay3 = 13.971374;
Config_MATLABStruct_M.az3 = 1.783211;
Config_MATLABStruct_M.bx1 = 777.2;
Config_MATLABStruct_M.by1 = 58.9;
Config_MATLABStruct_M.bz1 = 276.6;
Config_MATLABStruct_M.VR = 30;
Config_MATLABStruct_M.VT = 44.5;
Config_MATLABStruct_M.VO = 122.870185;
Config_MATLABStruct_M.a = 0.29;
Config_MATLABStruct_M.b = 62.89;
Config_MATLABStruct_M.c = 0.7;
Config_MATLABStruct_M.d = 10.99;
Config_MATLABStruct_M.e = 0.04;

Config_MATLABStruct= struct;
Config_MATLABStruct.cfg_N=Config_MATLABStruct_N;
Config_MATLABStruct.cfg_M=Config_MATLABStruct_M;
%% Model workspace
load_system(modelFile);
[~, modelName, ~] = fileparts(modelFile);
set_param(sprintf('%s/Constant',modelName),...
   'Value', 'cfg',  'OutDataTypeStr', 'Bus: Config_NM','ShowName', 'off');
mdlWks=get_param(...
    modelName,...
    "ModelWorkspace");
assignin(...
    mdlWks,...
    "cfg",...
    Config_MATLABStruct);

%% Attach dictionary
set_param(modelName, 'EnableAccessToBaseWorkspace', 'off');
set_param(...
    modelName,...
    "DataDictionary",...
   'NM_dd.sldd');
close_system(modelName, 1); 