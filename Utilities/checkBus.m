mdlWks = get_param('Heart3D','ModelWorkspace');
m_cfg = getVariable(mdlWks,'cfg');
dict_h = Simulink.data.dictionary.open('Heart.sldd'); 
template_h = Simulink.Bus.createMATLABStruct('HeartCfgBus', [], [1 1], dict_h);
compareStructs(m_cfg,template_h)
compareLeaves(m_cfg,template_h)
compareStructs(template_h,m_cfg)
compareLeaves(template_h,m_cfg)