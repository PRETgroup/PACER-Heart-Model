function [leadCfgBus,leadGroup] = read_leads(xsheetfile, sheetName, dataRange)
leads = readtable(xsheetfile,'Sheet', sheetName,Range = dataRange);
requiredCols = ["Type","x","y","z"];
missingCols = setdiff(requiredCols, string(leads.Properties.VariableNames));
if ~isempty(missingCols)
    error('read_leads:MissingColumns', ...
        'Lead sheet is missing required columns: %s', strjoin(missingCols, ', '));
end
leadCount = height(leads);
leadGroup=struct;
% Preallocate BusElement array
elements(1, leadCount) = Simulink.BusElement;
dict_Lead = Simulink.data.dictionary.open('Leads_type.sldd');
template_Lead = Simulink.Bus.createMATLABStruct('Lead', [], [1 1], dict_Lead);
for i = 1: leadCount
    template_Lead.e_pos.x=leads.x(i);
    template_Lead.e_pos.y=leads.y(i);
    template_Lead.e_pos.z=leads.z(i);
    switch lower(string(leads.Type(i)))
        case 'aring'
            template_Lead.e_type=int8(1);
        case 'atip'
            template_Lead.e_type=int8(2);
        case 'vring'
            template_Lead.e_type=int8(3);
        case 'vtip'
            template_Lead.e_type=int8(4);
        otherwise
            error('The lead type must be aring, atip, vring or vtip.')
    end
    
    leadGroup.(sprintf('lead_%d',i))=template_Lead;
    elements(i).Name = sprintf('lead_%d',i);
    elements(i).DataType = "Bus: Lead";
end
%% Create lead configuration bus
leadCfgBus = Simulink.Bus;
leadCfgBus.Elements = elements;
end