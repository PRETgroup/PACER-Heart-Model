% Copyright 2025 Weiwei Ai, University of Auckland.
% 
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
% 
%     http://www.apache.org/licenses/LICENSE-2.0
% 
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%%
%%Read excel data; If 'N3Cfg.mat' and 'N3Data.mat' already exist, this part
%%can be skipped.
filexls='Full3DHeart'; % The excel file name
% Specify the range of reading
Noderange='A2:AX944';
Node_P_range='D1:AX1'; % the parameter names
Pathrange='A2:O2771';
Path_P_range='E1:O1'; % the parameter names
Proberange='A2:E9';
% contains all configurations of heart model, which will be used to build a new heart model
filename='Heart_Full3D_Cfg.mat'; 
% contains all parameters of heart model, which will be used for simulation
datafile='Heart_Full3D_Data.mat'; 
[Node,Node_name,Node_pos,Path,Path_name,Probe,Probe_name,Probe_pos,cfgports]=PreCfgfcn_3D(filexls,Noderange,Node_P_range,Pathrange, Path_P_range, Proberange,filename,datafile);

%% Choose Nodes/Path library and build a heart model,which will be saved to the systempath.
rootPath='H:\GitHub\HeartModelPub';% change it according to your directory structure
path_var=[rootPath,filesep 'models']; % the path where the model will be saved
node_n = 'Node_N'; % The N type cell model library
node_m = 'Node_M'; % The M type cell model library
node_nm = 'Node_NM'; % The NM type cell model library
path = 'Path'; % The path model library
probe='Electrode'; % The EGM generation model library
HeartModel='Heart_Full3D'; % The name of the heart model
Buildmodel_3D_fcn(HeartModel,filename,node_n,node_m,node_nm,path,probe,path_var);
