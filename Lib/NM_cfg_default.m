%% ------------------------------------------------------------------
%  You can modify the values of the fields in Config_NM_MATLABStruct
%  and evaluate this cell to create/update this structure
%  in the MATLAB base workspace.
% -------------------------------------------------------------------


Config_NM_MATLABStruct = struct;
Config_NM_MATLABStruct.Bus_N = struct;
Config_NM_MATLABStruct.Bus_N.BCL = 0.814;
Config_NM_MATLABStruct.Bus_N.SD = 0.002;
Config_NM_MATLABStruct.Bus_N.f1 = 0.1;
Config_NM_MATLABStruct.Bus_N.f2 = 0.25;
Config_NM_MATLABStruct.Bus_N.sigma1sq = 0.0035;
Config_NM_MATLABStruct.Bus_N.sigma2sq = 0.007;
Config_NM_MATLABStruct.Bus_N.d2 = 1281;
Config_NM_MATLABStruct.Bus_N.ERP = 0.1615;
Config_NM_MATLABStruct.Bus_N.d0 = -773.2;
Config_NM_MATLABStruct.Bus_N.MDP = -85.3;
Config_NM_MATLABStruct.Bus_N.VT = 23.81;
Config_NM_MATLABStruct.Bus_N.VR = 47.94;
Config_NM_MATLABStruct.Bus_N.Vh = -4.0;
Config_NM_MATLABStruct.Bus_N.hr = 0.1;
Config_NM_MATLABStruct.Bus_N.hs = 35;
Config_NM_MATLABStruct.Bus_N.s = 5;
Config_NM_MATLABStruct.Bus_N.j = 0;
Config_NM_MATLABStruct.Bus_N.m = 1;
Config_NM_MATLABStruct.Bus_N.h = 0.2;
Config_NM_MATLABStruct.Bus_N.f = 0.1;
Config_NM_MATLABStruct.Bus_N.r = 0.5;
Config_NM_MATLABStruct.Bus_M = struct;
Config_NM_MATLABStruct.Bus_M.ax0 = -8.7;
Config_NM_MATLABStruct.Bus_M.ay0 = -190.9;
Config_NM_MATLABStruct.Bus_M.az0 = -190.4;
Config_NM_MATLABStruct.Bus_M.ax1 = -23.6;
Config_NM_MATLABStruct.Bus_M.ay1 = -45.5;
Config_NM_MATLABStruct.Bus_M.az1 = -12.9;
Config_NM_MATLABStruct.Bus_M.ax2 = -6.9;
Config_NM_MATLABStruct.Bus_M.ay2 = 75.9;
Config_NM_MATLABStruct.Bus_M.az2 = 6826.5;
Config_NM_MATLABStruct.Bus_M.ax3 = -17.809705;
Config_NM_MATLABStruct.Bus_M.ay3 = 13.971374;
Config_NM_MATLABStruct.Bus_M.az3 = 1.783211;
Config_NM_MATLABStruct.Bus_M.bx1 = 777.2;
Config_NM_MATLABStruct.Bus_M.by1 = 58.9;
Config_NM_MATLABStruct.Bus_M.bz1 = 276.6;
Config_NM_MATLABStruct.Bus_M.VR = 30;
Config_NM_MATLABStruct.Bus_M.VT = 44.5;
Config_NM_MATLABStruct.Bus_M.VO = 122.870185;
Config_NM_MATLABStruct.Bus_M.a = 0.29;
Config_NM_MATLABStruct.Bus_M.b = 62.89;
Config_NM_MATLABStruct.Bus_M.c = 0.7;
Config_NM_MATLABStruct.Bus_M.d = 10.99;
Config_NM_MATLABStruct.Bus_M.e = 0.04;

% 1. Open the Simulink Data Dictionary
dictObj = Simulink.data.dictionary.open('NM_dd.sldd');

% 2. Access the Design Data section
sectionObj = getSection(dictObj, 'Design Data');

% 3. Find the parameter 'cfg_default' inside the dictionary
paramEntry = getEntry(sectionObj, 'cfg_default_nm');

% 4. Retrieve the actual Simulink.Parameter object from the entry
paramObj = getValue(paramEntry);

% 5. Assign your MATLAB struct to the parameter's Value field
paramObj.Value = Config_NM_MATLABStruct;

% 6. Ensure the DataType is explicitly bound to your Bus
paramObj.DataType = 'Bus: Config_NM';

% 7. Update the entry in the dictionary with the modified parameter object
setValue(paramEntry, paramObj);

% 8. Save changes and close the dictionary connection
saveChanges(dictObj);
close(dictObj);

clear dictObj sectionObj paramEntry paramObj Config_NM_MATLABStruct;
disp('cfg_default successfully updated with Config_NM_MATLABStruct values!');