function PreBuild_unified(arrays)
arguments
    arrays = 'NaN';
end

%%
% Read in user inputs for the reading of excel file and saving of model
% (loop ensures the user puts in the correct information for it to work)
if ~isstruct(arrays)
    while(1)
        answer = dialogoptions();
        if isempty(answer)
            empty_answer = questdlg('Do you really want to cancel?', ...
                'Cancel Model Creation','Yes','No','Yes');
            switch empty_answer
                case 'Yes'
                    return
                case 'No'
            end
        elseif ischeck(answer)
            break
        end
    end
    filexls=answer{1}; % The excel file name
    % The name of the heart model
    HeartModel=answer{2};
    % contains all configurations of heart model, which will be used to build a new heart model
    filename=strcat('N3Cfg_',erase(HeartModel,'Heart_'),'.mat');
    % contains all parameters of heart model, which will be used for simulation
    datafile=strcat('N3Data_',erase(HeartModel,'Heart_'),'.mat');
    % Specify the range of reading
    Noderange=answer{3};
    Node_P_range= answer{4}; % the parameter names
    Pathrange= answer{5};
    Path_P_range= answer{6};% the parameter names
    Proberange= answer{7};
    Standalone = ismember(lower(answer{8}),{'true','1','yes'});
else
    while(1)
        answer = dialogoptions_sml();
        if isempty(answer)
            empty_answer = questdlg('Do you really want to cancel?', ...
                'Cancel Model Creation', ...
                'Yes (revert to original model)','No (continue with creation)',...
                'Yes (revert to original model)');
            switch empty_answer
                case 'Yes (revert to original model)'
                    return
                case 'No'
            end
        elseif ischeck_sml(answer)
            break
        end
    end
    % The name of the heart model
    HeartModel=answer{1};
    % contains all configurations of heart model, which will be used to build a new heart model
    filename=strcat('N3Cfg_',erase(HeartModel,'Heart_'),'.mat');
    % contains all parameters of heart model, which will be used for simulation
    datafile=strcat('N3Data_',erase(HeartModel,'Heart_'),'.mat');
    filexls = 'NaN';
    Noderange = 'NaN';
    Node_P_range = 'NaN';
    Pathrange = 'NaN';
    Path_P_range = 'NaN';
    Proberange = 'NaN';
    Standalone = false;
end
[Node,Node_name,Node_pos,Path,Path_name,...
    Probe,Probe_name,Probe_pos,cfgports]=PreCfgfcn_unified(filexls,...
        Noderange,Node_P_range,Pathrange,Path_P_range,Proberange,filename,datafile,arrays);

%% Choose Nodes/Path library and build a heart model,which will be saved to the systempath.
rootPath=pwd;% may result in errors if running file from within 'src'
path_var=[rootPath,filesep 'models']; % the path where the model will be saved
folder = 'Libs_unified';
library = [rootPath,filesep 'Lib' filesep folder];% the components library path
node_n = append(folder,'/Node_N_V6'); % The N type cell model library
node_m = append(folder,'/Node_M_V4'); % The M type cell model library
node_nm = append(folder,'/Node_NM_V4'); % The NM type cell model library
path = append(folder,'/Path_V3'); % The path model library
probe=append(folder,'/Electrode'); % The EGM generation model library
Buildmodel_fcn(HeartModel,filename,node_n,node_m,node_nm,...
    path,probe,path_var,library,Standalone);
% If this function was started from Heart_Editing_GUI then incorporate it into
% CLSfixed
if isstruct(arrays) && isfield(arrays,'model')
    load_system(HeartModel)
    models={'CLSfixed.slx', 'CLSfixed_pace.slx', 'CLSfixed_nopace.slx'};
    modelName = models{arrays.pacemaker};
    c = load_system(modelName);
    if arrays.pacemaker == 1
        replace_block(c,'Name','Heart', append(HeartModel,'/Heart'),'noprompt')
        replace_block(c,'Name','Heart1', append(HeartModel,'/Heart'),'noprompt')
    else
        replace_block(c,'Name','Heart', append(HeartModel,'/Heart'),'noprompt')
    end
    save_system(c,[path_var, filesep, modelName])
    assignin('base','filename',filename)
    assignin('base','datafile',datafile)
end
end

function answer = dialogoptions()
%popup box for the user defined inputs
prompt = {'Enter input excel file name:','Heart model name:', 'Node range:',...
        'Node Parameter range:', 'Path range:',...
        'Path Parameter range:','Probe range:', 'Standalone Heart:'};
dlgtitle = 'Input';
fieldsize = [1 30; 1 30; 1 20; 1 20; 1 20; 1 20; 1 20; 1 20];
definput = {'Heart_N3_second.xlsx','Heart_example', 'A2:AW44'...
        'D1:AW1','A2:O55','E1:O1','A2:E9', 'Yes'};
answer = inputdlg(prompt,dlgtitle,fieldsize,definput);
end

function answer = dialogoptions_sml()
%popup box for the user defined inputs
prompt = {'Heart model name:'};
dlgtitle = 'Input';
fieldsize = [1 30];
definput = {'Heart_example'};
answer = inputdlg(prompt,dlgtitle,fieldsize,definput);
end

function result=ischeck(cell_array)
% Function to check if the inputs are correct
for idx=1:length(cell_array)
    if isempty(cell_array{idx})
        f =msgbox("Missing value: "+cell_array{idx},"Error","error");
        result = false;
        waitfor(f);
        return 
    elseif (idx ==1) && ~exist(char(cell_array{idx}),'file')
        f = msgbox("Excel file does not exist: "+cell_array{idx},"Error","error");
        result = false;
        waitfor(f);
        return 
    elseif (idx == 2) && isfile(['models\' cell_array{idx} '.slx'])
        f = msgbox("Model already exists: "+cell_array{idx},"Error","error");
        result = false;
        waitfor(f);
        return 
    elseif (idx >2 && idx <length(cell_array)) && ~contains(cell_array{idx},':')
        f = msgbox("Range incomprehensible: "+cell_array{idx},"Error","error");
        result = false;
        waitfor(f);
        return
    elseif (idx ==(length(cell_array))) && ~ismember(lower(cell_array{idx}),...
            {'true','1','yes','false','0','no'})
        f = msgbox("Response incomprehensible: "+cell_array{idx},"Error","error");
        result = false;
        waitfor(f);
        return
    end
end
result = true;
end

function result=ischeck_sml(cell_array)
% Function to check if the inputs are correct for the smaller version
if isempty(cell_array{1})
    f =msgbox("Missing Value: "+cell_array{1},"Error","error");
    result = false;
    waitfor(f);
    return 
elseif isfile(['models\' cell_array{1} '.slx'])
    f = msgbox("Model already exists: "+cell_array{1},"Error","error");
    result = false;
    waitfor(f);
    return 
end
result = true;
end