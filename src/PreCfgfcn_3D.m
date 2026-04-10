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

function [Node,Node_name,Node_pos,Path,Path_name,Probe,Probe_name,Probe_pos,cfgports]=PreCfgfcn_3D(filexls,Noderange,Node_P_range,Pathrange, Path_P_range, Proberange,filename,datafile)

%% Read paras from xlsx
% Read Node cfg data
[Node,Node_name,Node_Raw] = xlsread(filexls, 'Node_second',Noderange);
save (filename, 'Node');
save (filename, 'Node_name','-append');
save (filename, 'Node_Raw', '-append');
Node_pos=Node(:,46:48); % x,y,z
save (filename, 'Node_pos', '-append');
[~,Node_para,~] = xlsread(filexls, 'Node_second',Node_P_range);
save (filename, 'Node_para', '-append');
% Read Path cfg data
[Path,Path_name,Path_Raw] = xlsread(filexls, 'Path_second',Pathrange);
save (filename, 'Path', '-append');
save (filename, 'Path_name', '-append');
save (filename, 'Path_Raw', '-append');
[~,Path_para,~] = xlsread(filexls, 'Path_second',Path_P_range);
save (filename, 'Path_para', '-append');
% Read Probe cfg data
[Probe,Probe_name,Probe_Raw] = xlsread(filexls, 'Probe',Proberange);
save (filename, 'Probe', '-append');
save (filename, 'Probe_name', '-append');
save (filename, 'Probe_Raw', '-append');
Probe_pos=Probe(:,2:4);
save (filename, 'Probe_pos', '-append');
load(filename);
% Create lookup table for parameters update
[r c]=size(Node);
Node_lookup=zeros(r,c);
[r c]=size(Path);
Path_lookup=zeros(r,c);

%% Node Assembly
Nodecfg={'24'}; % number of params
cfgdata_second=[];
m=0;
params_M=26;
params_N=24;
params_NM=params_N+params_M;
for i=1:size(Node,1) %iterates through node list
    % Which type of node
    if strcmp(Node_name{i,2},'M')
        Nodecfg1={'26'};        
        cfgdata_second=horzcat(cfgdata_second,Node(i,23:48));
        m1=m+1; % the first para
        m=m+params_M; % the last one; (including x,y,z)
        m2=m-3; %  the last para (excluding x,y,z)
        start=23;
        endn=45;
        Node_lookup(i,start:endn)=m1:m2; % para ax0 to para e
        Node_lookup(i,46:48)=m-2:m; % x,y,z
        Node_lookup(i,49:50)=[0 0]; %??
    else if strcmp(Node_name{i,2},'N')
            Nodecfg1={'24'};            
            cfgdata_second=horzcat(cfgdata_second,Node(i,2:22),Node(i,46:48));
            m1=m+1; % the first para
            m=m+params_N; % the last one; (including x,y,z)
            m2=m-3; %  the last para (excluding x,y,z)
            start=2;
            endn=22;       
            Node_lookup(i,start:endn)=m1:m2; % para BCL to para r
            Node_lookup(i,46:48)=m-2:m; % x,y
            Node_lookup(i,49:50)=[0 0];
        else if strcmp(Node_name{i,2},'NM')
                Nodecfg1={'52'};                
                cfgdata_second=horzcat(cfgdata_second,Node(i,2:22),Node(i,46:48),Node(i,23:48),1,1);
                m1=m+1; % the first para
                m=m+params_NM; % the last one; (including x,y,z)
                m2=m-3; %  the last para (excluding x,y,z)
                start=2;
                endn=45;
                Node_lookup(i,start:22)=m1:m1+20;
                Node_lookup(i,23:endn)=m1+params_N:m2;
                Node_lookup(i,46:48)=m-2:m;
                m=m+2; % add dij, dji to control the path in between
                Node_lookup(i,49:50)=m-1:m;
            else
                error('The dimension of Nodecfg does not match');
            end
        end
    end
    
    if i>=2
        Nodecfg=strcat(Nodecfg,',',Nodecfg1);
    end
    
end

%% Path Assembly
Pathcfg={'11'};
for i=1:size(Path_name,1)    
    cfgdata_second=horzcat(cfgdata_second,Path(i,3:13));
    m1=m+1;
    m=m+11;
    m2=m;
    Path_lookup(i,3:13)=m1:m2;
    if i>=2
        Pathcfg=strcat(Pathcfg,',11');      
    end
end

Node_lookup(:,1)=Node(:,1);
Path_lookup(:,1:2)=Path(:,1:2);

%% Probe Assembly
ARN=0;
ATN=0;
VRN=0;
VTN=0;

for i=1:size(Probe,1) %iterate through probe list
    % Which type of probe
    if strcmp(Probe_name{i,1},'Aring')
        ARN=ARN+1;
        cfgdata_second=horzcat(cfgdata_second,Probe(i,2:4));
        
    else if strcmp(Probe_name{i,1},'Atip')
            ATN=ATN+1;
            cfgdata_second=horzcat(cfgdata_second,Probe(i,2:4));
            
        else if strcmp(Probe_name{i,1},'Vring')
                VRN=VRN+1;
                cfgdata_second=horzcat(cfgdata_second,Probe(i,2:4));
                
            else if strcmp(Probe_name{i,1},'Vtip')
                    VTN=VTN+1;
                    cfgdata_second=horzcat(cfgdata_second,Probe(i,2:4));                    
                else
                    error('Probe type error!');
                end
            end
        end
    end
end

Probecfg=int2str(ARN*3+ATN*3+VRN*3+VTN*3+4);

cfgdata_second=horzcat(cfgdata_second,ARN,ATN,VRN,VTN);
cfgports=strcat('[',Nodecfg,',',Pathcfg,',',Probecfg,']');
save (datafile,'cfgdata_second');
save (filename, 'cfgports','Node_lookup','Path_lookup','-append');
end
