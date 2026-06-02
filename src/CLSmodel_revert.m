
clear all;
bdclose('all');
path_var=pwd;
if ~contains('models',path_var)
    path_var = [path_var, filesep 'models'];
end
models={'CLSfixed', 'CLSfixed_pace', 'CLSfixed_nopace'};
%models = {'CLSfixed'};
HeartModel = 'HeartV11';
load_system(HeartModel)
% Revert the heart model to the original one
for i=1:length(models)
    modelName = models{i};
    c = load_system(modelName);
    if i == 1
        replace_block(c,'Name','Heart', append(HeartModel,'/Heart'),'noprompt')
        replace_block(c,'Name','Heart1', append(HeartModel,'/Heart'),'noprompt')
    else
        replace_block(c,'Name','Heart', append(HeartModel,'/Heart'),'noprompt')
    end
    save_system(c,[path_var, filesep, modelName])
end
