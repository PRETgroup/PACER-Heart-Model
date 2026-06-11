%% ------------------------------------------------------------------
%  You can modify the values of the fields in Config_MATLABStruct
%  and evaluate this cell to create/update this structure
%  in the MATLAB base workspace.
%  Assign the value of the struct to the parameter 'cfg_default'
%  in the dictionary as the initial value of the signal cfg.
% -------------------------------------------------------------------


Config_MATLABStruct = struct;
Config_MATLABStruct.CVi2j = 57;
Config_MATLABStruct.Dij = 1;
Config_MATLABStruct.aij = 0.01;
Config_MATLABStruct.bij = 3.5;
Config_MATLABStruct.cij = 0;
Config_MATLABStruct.CVj2i = 57;
Config_MATLABStruct.Dji = 1;
Config_MATLABStruct.aji = 0.3;
Config_MATLABStruct.bji = 62.89;
Config_MATLABStruct.cji = 10.99;

% 1. Open the Simulink Data Dictionary
dictObj = Simulink.data.dictionary.open('Path_dd.sldd');

% 2. Access the Design Data section
sectionObj = getSection(dictObj, 'Design Data');

% 3. Find the parameter 'cfg_default' inside the dictionary
paramEntry = getEntry(sectionObj, 'cfg_default_path');

% 4. Retrieve the actual Simulink.Parameter object from the entry
paramObj = getValue(paramEntry);

% 5. Assign your MATLAB struct to the parameter's Value field
paramObj.Value = Config_MATLABStruct;

% 6. Ensure the DataType is explicitly bound to your Bus
paramObj.DataType = 'Bus: Config_path';

% 7. Update the entry in the dictionary with the modified parameter object
setValue(paramEntry, paramObj);

% 8. Save changes and close the dictionary connection
saveChanges(dictObj);
close(dictObj);

clear dictObj sectionObj paramEntry paramObj Config_MATLABStruct;
disp('cfg_default successfully updated with Config_MATLABStruct values!');