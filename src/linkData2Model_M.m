%% ------------------------------------------------------------------
%  Create the cfg for M type cell;
%  You can modify the values of the fields in Config_MATLABStruct
%  Assign the value of the struct to the parameter 'cfg'
%  Link the data type definition to the model
% -------------------------------------------------------------------
 modelFile='models/Node_M_3D.slx';

Config_MATLABStruct = struct;
Config_MATLABStruct.ax0 = -8.7;
Config_MATLABStruct.ay0 = -190.9;
Config_MATLABStruct.az0 = -190.4;
Config_MATLABStruct.ax1 = -23.6;
Config_MATLABStruct.ay1 = -45.5;
Config_MATLABStruct.az1 = -12.9;
Config_MATLABStruct.ax2 = -6.9;
Config_MATLABStruct.ay2 = 75.9;
Config_MATLABStruct.az2 = 6826.5;
Config_MATLABStruct.ax3 = -17.809705;
Config_MATLABStruct.ay3 = 13.971374;
Config_MATLABStruct.az3 = 1.783211;
Config_MATLABStruct.bx1 = 777.2;
Config_MATLABStruct.by1 = 58.9;
Config_MATLABStruct.bz1 = 276.6;
Config_MATLABStruct.VR = 30;
Config_MATLABStruct.VT = 44.5;
Config_MATLABStruct.VO = 122.870185;
Config_MATLABStruct.a = 0.29;
Config_MATLABStruct.b = 62.89;
Config_MATLABStruct.c = 0.7;
Config_MATLABStruct.d = 10.99;
Config_MATLABStruct.e = 0.04;
% 
%% Model workspace
load_system(modelFile);
[~, modelName, ~] = fileparts(modelFile); 
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
   'M_dd.sldd');
close_system(modelName, 1); 