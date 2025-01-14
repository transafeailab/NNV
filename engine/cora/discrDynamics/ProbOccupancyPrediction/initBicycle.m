function [HA,options,stateField,inputField]=initBicycle(varargin)
% changed: 02-November-2009


directory=cd;

%set options---------------------------------------------------------------
options.tStart=0; %start time
options.tFinal=0.5; %final time
%options.tFinal=0.5; %final time
options.startLoc=1; %initial location
options.finalLoc=0; %final location
options.timeStep=0.05; %time step size for reachable set computation
options.taylorTerms=4; %number of taylor terms for reachable sets
options.zonotopeOrder=10; %zonotope order
options.polytopeOrder=6; %polytope order
options.projectedDimensions=[1 2];
options.reductionInterval=1e3;
options.target='vehicleDynamics';
options.guardIntersect='polytope';
%--------------------------------------------------------------------------

%specify continuous dynamics-----------------------------------------------
accSlow=linearSys('accEidSlow',[0 1;0 0],[0;2.5]); %acceleration
accFast=nonlinearSys('accEidBicycle',2,1,@accSysEidFastBicycle); %acceleration
dec=linearSys('decEid',[0 1;0 0],[0;7]); %deceleration
sL=linearSys('sL',[0 1;0 0],[0;0]); %speed limit
sS=zeroDynSys('sS',2); %standstill
%--------------------------------------------------------------------------

%specify transitions-------------------------------------------------------

%reset map for all transitions
reset.A=eye(2); 
reset.b=zeros(2,1);

%long distance l
l=[0 1e3]; %-->probabilities may only escape in driving direction
maxSpeed=[19 19.99];
zeroSpeed=[0.001 0.01];
accChangeSpeed=[2.5 2.55];

%specify invariant
inv=intervalhull([l; 0 20]); %invariant for all locations

%guard sets
IHstop=intervalhull([l; zeroSpeed]);
IHmaxSpeed=intervalhull([l; maxSpeed]);  
IHaccChange=intervalhull([l; accChangeSpeed]); 

%specify transitions
tran1{1}=transition(IHaccChange,reset,2,'a','b'); 
tran2{1}=transition(IHmaxSpeed,reset,3,'a','b'); 
tran3=[]; 
tran4{1}=transition(IHstop,reset,5,'a','b');
tran5=[];

%--------------------------------------------------------------------------

%specify locations              
loc{1}=location('accSlow',1,inv,tran1,accSlow);
loc{2}=location('accFast',2,inv,tran2,accFast);
loc{3}=location('sL',3,inv,tran3,sL);
loc{4}=location('dec',4,inv,tran4,dec);
loc{5}=location('sS',5,inv,tran5,sS);


%specify hybrid automaton
HA=hybridAutomaton(loc);

%Initialize partition------------------------------------------------------
stateField=partition([0, 200;... %position in m
                      0, 20],... %velocity in m/s         
                     [40;10]);
inputField=partition([-1,1],...  %acceleartion in m/s^2
                     6);  
%--------------------------------------------------------------------------

if nargin==1
    cd(directory);
end