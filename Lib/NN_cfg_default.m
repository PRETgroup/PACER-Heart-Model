%% ------------------------------------------------------------------
%  You can modify the values of the fields in Config_MATLABStruct
%  and evaluate this cell to create/update this structure
%  in the MATLAB base workspace.
%  Assign the value of the struct to the parameter 'cfg_default'
%  in the dictionary as the initial value of the signal cfg.
% -------------------------------------------------------------------


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

% 1. Open the Simulink Data Dictionary
dictObj = Simulink.data.dictionary.open('N_dd.sldd');

% 2. Access the Design Data section
sectionObj = getSection(dictObj, 'Design Data');

% 3. Find the parameter 'cfg_default' inside the dictionary
paramEntry = getEntry(sectionObj, 'cfg_default');

% 4. Retrieve the actual Simulink.Parameter object from the entry
paramObj = getValue(paramEntry);

% 5. Assign your MATLAB struct to the parameter's Value field
paramObj.Value = Config_MATLABStruct;

% 6. Ensure the DataType is explicitly bound to your Bus
paramObj.DataType = 'Bus: Config';

% 7. Update the entry in the dictionary with the modified parameter object
setValue(paramEntry, paramObj);

% 8. Save changes and close the dictionary connection
saveChanges(dictObj);
close(dictObj);

clear dictObj sectionObj paramEntry paramObj Config_MATLABStruct;
disp('cfg_default successfully updated with Config_MATLABStruct values!');

