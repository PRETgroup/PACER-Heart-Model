% Copyright 2019 Weiwei Ai.
% This program is released under license GPL version 3.
%%
clear all;
%bdclose('all');
path_var=pwd;
if ~contains('models',path_var)
    path_var = [path_var, filesep 'models'];
end
warning('off','all')
% Opening Main GUI which determines whether to edit model network
% structure, parameters, and add pacemaker
global outputs 
outputs = main_settings();
Heart_GUI_preset(outputs);
%Millisecond: parasNormal, Multi[2,3,_Bradycardia]
%Second: parasMulti[_second,_AV_block]
if outputs.units == 2
    switch outputs.param
        case 'Normal'        %1
            updatePara='parasMulti_second.mat';
        case 'AV Block' %2
            updatePara='parasMulti_AV_block.mat';
        otherwise 
            updatePara='parasMulti_second.mat';
    end
else
    switch outputs.param
        case 'Normal'        %1
            updatePara='parasNormal.mat';
        case 'parasMulti' %2
            updatePara='parasMulti.mat';
        case 'parasMulti2' %3
            updatePara='parasMulti2.mat';
        case 'parasMulti3' %4
            updatePara='parasMulti3.mat';
        case 'Bradycardia' %5
            updatePara = 'parasMulti_Bradycardia.mat';
        otherwise 
            updatePara='parasNormal.mat';
    end
end
assignin('base','sens_units',outputs.units) % Sensing charts Chart (unit) subsystem
%Prepare the parameters
if outputs.units == 2 
    filename='4_Node_Heart_Network_Example_Cfg.mat'; 
    datafile='4_Node_Heart_Network_Example_Data.mat';
    pathsheet='Path_second';
    nodesheet='Node_second'; 
    assignin('base','solvertime',5); % solving time for the GUI cells 
    assignin('base','stepsize',0.0005); % step size for solving the GUI cells and the CLS sample time
    assignin('base','timescale','s'); % time scale for GUI plots
    assignin('base','buffer',0.599); % for Libs_unified/Path_V3/Path Buffer_i and Buffer_j
    assignin('base','unit_conversion',1); % used with the N node ms/s setting in RR
    assignin('base','stoptime',2) % CLSfixed initial stop time
elseif outputs.units == 1
    filename='4_Node_Heart_Network_Example_Cfg.mat'; 
    datafile='4_Node_Heart_Network_Example_Data.mat'; 
    pathsheet='Path'; 
    nodesheet='Node'; 
    assignin('base','solvertime',5000);
    assignin('base','stepsize',0.1);
    assignin('base','timescale','ms');
    assignin('base','buffer',599);
    assignin('base','unit_conversion',1000);
    assignin('base','stoptime',2000)
end

% Extract the node classification data from the xlsx file
[~,~,nodes_raw]=xlsread('4_Node_Heart_Network_Example.xlsx',nodesheet);
[~,~,path_raw]=xlsread('4_Node_Heart_Network_Example.xlsx',pathsheet);
[~,~,probes_raw]=xlsread('4_Node_Heart_Network_Example.xlsx','Probe');
% Edit the network model
if outputs.editmodel
    global node_atts
    global node_atts_copy
    global path_atts
    global path_atts_copy
    global params
    global nodes_name %potentially join the nodes_name into the front of node_atts
    global probes_name 
    temp = nodes_raw(:,2:end);
    temp(:,end-2) = [];
    temp(end,:) = [];
    assignin('base','node_atts',temp);
    assignin('base','node_atts_copy',temp);
    assignin('base','path_atts',path_raw);
    assignin('base','path_atts_copy',path_raw);

    temp1 = nodes_raw(:,1:2);
    temp1(end,:) = [];
    assignin('base','nodes_name',temp1);
    temp2 = probes_raw(2:end,1:5);
    assignin('base','probes_name',temp2);
    Heart_Editing_GUI(filename,nodes_name,probes_name,params,node_atts,node_atts_copy,path_atts,path_atts_copy,timescale,outputs.pacemaker);
end

% contains all configurations of heart model
load(filename);
% contains all parameters of heart model
load(datafile);
% Load in the new parameter range
load(updatePara);
% Global parameters
assignin('base','paras_length',length(pp))
assignin('base','cfg_length',length(cfgdata))
assignin('base','pNode_length',length(pNode))
assignin('base','pPath_length',length(pPath))
models={'CLSfixed', 'CLSfixed_pace', 'CLSfixedExample3'};
% Specify the model name
modelName = models{outputs.pacemaker};
% Specify the model path
mdl=[path_var,filesep, modelName];
% Specify the data save path
savepath=[path_var,filesep 'Cells.mat'];

% In the model, there should be a S-function to save data to the same structure of the GUI.
Heart_GUI(mdl,modelName,filename,savepath,nodes_raw,probes_raw); 