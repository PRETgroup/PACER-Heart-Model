%% ------------------------------------------------------------------
%  Create the cfg for M type cell;
%  You can modify the values of the fields in Config_MATLABStruct
%  Assign the value of the struct to the parameter 'cfg'
%  Link the data type definition to the model
% -------------------------------------------------------------------
 modelFile='models/Node_N_3D.slx';

Config_MATLABStruct = struct;
Config_MATLABStruct.BCL = 0.814;
Config_MATLABStruct.SD = 0.002;
Config_MATLABStruct.f1 = 0.1;
Config_MATLABStruct.f2 = 0.25;
Config_MATLABStruct.sigma1sq = 0.0035;
Config_MATLABStruct.sigma2sq = 0.007;
Config_MATLABStruct.d2 = 1281;
Config_MATLABStruct.ERP = 0.1615;
Config_MATLABStruct.d0 = -773.2;
Config_MATLABStruct.MDP = -85.3;
Config_MATLABStruct.VT = 23.81;
Config_MATLABStruct.VR = 47.94;
Config_MATLABStruct.Vh = -4.0;
Config_MATLABStruct.hr = 0.1;
Config_MATLABStruct.hs = 35;
Config_MATLABStruct.s = 5;
Config_MATLABStruct.j = 0;
Config_MATLABStruct.m = 1;
Config_MATLABStruct.h = 0.2;
Config_MATLABStruct.f = 0.1;
Config_MATLABStruct.r = 0.5;
% 
%% Model workspace
load_system(modelFile);
[~, modelName, ~] = fileparts(modelFile); 
% set the constant block
set_param(sprintf('%s/Constant',modelName),...
   'Value', 'cfg',  'OutDataTypeStr', 'Bus: Config_N','ShowName', 'off');
mdlWks=get_param(...
    modelName,...
    "ModelWorkspace");
assignin(...
    mdlWks,...
    "cfg",...
    Config_MATLABStruct);
%% Attach dictionary
set_param(...
    modelName,...
    "DataDictionary",...
   'N_dd.sldd');
close_system(modelName, 1); 