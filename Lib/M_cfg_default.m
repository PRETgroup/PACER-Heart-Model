%% ------------------------------------------------------------------
%  You can modify the values of the fields in Config_MATLABStruct
%  and evaluate this cell to create/update this structure
%  in the MATLAB base workspace.
%  Assign the value of the struct to the parameter 'cfg_default'
%  in the dictionary as the initial value of the signal cfg.
% -------------------------------------------------------------------


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

% 1. Open the Simulink Data Dictionary
dictObj = Simulink.data.dictionary.open('M_dd.sldd');

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