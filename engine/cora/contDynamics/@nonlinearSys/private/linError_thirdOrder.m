function [errorStat, errorDyn, errorInt] = linError_thirdOrder(obj, options, Rall, Rdelta, Rdiff)
% linError - computes the linearization error
%
% Syntax:  
%    [obj] = linError_thirdOrder(obj,options)
%
% Inputs:
%    obj - nonlinear system object
%    options - options struct
%    Rall - reachable set for the whole time interval
%    Rdelta - reachable set at the beginning of the time interval
%    Rdiff - difference between the reachable set at the beginning of the
%            time interval and the reachable set of the whole time interval
%
% Outputs:
%    errorStat - zonotope overapproximating the static linearization error
%    errorDyn - zonotope overapproximating the dynamic linearization error
%    errorInt - interval overapproximating the overall linearization error
%
% Example: 
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: 

% Author:       Matthias Althoff, Niklas Kochdumper
% Written:      21-August-2012
% Last update:  18-March-2016
%               25-July-2016 (intervalhull replaced by interval)
%               22-January-2018 (NK, fixed error for the sets)
%               08-February-2018 (NK, higher-order-tensors + clean-up)
% Last revision:---

%------------- BEGIN CODE --------------

%compute interval of reachable set
dx = interval(Rall);
totalInt_x = dx + obj.linError.p.x;

%compute intervals of input
du = interval(options.U);
totalInt_u = du + obj.linError.p.u;

%obtain intervals and combined interval z
dz = [dx; du];

%compute zonotope of state and input
Rred = reduce(Rdelta,options.reductionTechnique,options.errorOrder);
if isa(Rall,'zonotope')
    Rred_zono = reduce(Rdelta,options.reductionTechnique,options.errorOrder);
    Rred_diff = reduce(Rdiff,options.reductionTechnique,options.errorOrder);   
    Rred_all = reduce(Rall,options.reductionTechnique,options.errorOrder);
else
    Rred_zono = reduce(zonotope(Rdelta),options.reductionTechnique,options.errorOrder);
    Rred_diff = reduce(zonotope(Rdiff),options.reductionTechnique,options.errorOrder);
    Rred_all = reduce(zonotope(Rall),options.reductionTechnique,options.errorOrder);
end
Z=cartesianProduct(Rred,options.U);
Z_zono=cartesianProduct(Rred_zono,options.U);
Z_diff=cartesianProduct(Rred_diff,options.U);
Z_all = cartesianProduct(Rred_all,options.U);


% second-order error
H = obj.hessian(obj.linError.p.x, obj.linError.p.u);

error_secondOrder_dyn = 0.5*(mixedMultiplication(Z_zono,Z_diff,H) ...
              + mixedMultiplication(Z_diff,Z_zono,H) ...
              + quadraticMultiplication(Z_diff,H));
          
error_secondOrder_stat = 0.5*quadraticMultiplication(Z, H);


% third-order error
if options.tensorOrder == 3
    
    % evaluate the third-order tensor
    if isfield(options,'lagrangeRem') && isfield(options.lagrangeRem,'method') && ...
       ~strcmp(options.lagrangeRem.method,'interval')

        % create taylor models or zoo-objects
        [objX,objU] = initRangeBoundingObjects(totalInt_x,totalInt_u,options);

        % evaluate third order tensor 
        T = obj.thirdOrderTensor(objX, objU);

    else
        T = obj.thirdOrderTensor(totalInt_x, totalInt_u);
    end
    
    % calculate the Lagrange remainder term
    for i=1:length(T(:,1))
        error_sum = interval(0,0);
        for j=1:length(T(1,:))
            error_tmp(i,j) = dz.'*T{i,j}*dz;
            error_sum = error_sum + error_tmp(i,j) * dz(j);
        end
        error_thirdOrder_old(i,1) = 1/6*error_sum;
    end

    error_thirdOrder_dyn = zonotope(error_thirdOrder_old);
    error_thirdOrder_dyn = reduce(error_thirdOrder_dyn,'girard',options.zonotopeOrder);
    
else
    
    T = obj.thirdOrderTensor(obj.linError.p.x, obj.linError.p.u); 
    error_thirdOrder_dyn = 1/6*cubicMultiplication(Z_all, T);
end


% higher-order error
remainder = interval(zeros(length(dx),1),zeros(length(dx),1));

if options.tensorOrder > 4
    
   % exact evaluation of intermediate taylor terms
   for i = 4:options.tensorOrder-1
      handle = obj.tensors{i-3};
      remainder =  remainder + handle(obj.linError.p.x, obj.linError.p.u,dx,du);
   end
   
   % lagrange remainder over-approximation of the last taylor term
   handle = obj.tensors{options.tensorOrder-3};
   remainder =  remainder + handle(totalInt_x, totalInt_u,dx,du);
end


%combine results
errorDyn = error_secondOrder_dyn + error_thirdOrder_dyn + zonotope(remainder);
errorStat= error_secondOrder_stat;

errorDyn = reduce(errorDyn,'girard',options.intermediateOrder);
errorStat = reduce(errorStat,'girard',options.intermediateOrder);

errorIHabs = abs(interval(errorDyn) + interval(errorStat));
errorInt = supremum(errorIHabs);

%------------- END OF CODE --------------

% OLD STUFF:

% if ~isempty(options.preT)
%     %find index
%     index = round(obj.linError.p.x(end)/options.preT{1}.stepSize_1);
%     
%     %check correctness
%     %if (IH_x + obj.linError.p.x) <= options.preT{index}.IH
%         T = options.preT{index}.T;
%     %end
% else

%T = thirdOrderTensor_reduced(totalInt_x, totalInt_u);
% toc
%tic
%T = thirdOrderTensor_reduced2_parallel(totalInt_x, totalInt_u);
%toc


% %ACTIVATE FOR vanDerPOL!!!!!
% %interval evaluation 
% for i=1:length(T(:,1))
%     error_sum = 0;
%     for j=1:length(T(1,:))
%         T_abs = sup(abs(T{i,j}));
%         error_tmp(i,j) = dz_abs'*T_abs*dz_abs;
%         error_sum = error_sum + error_tmp(i,j) * dz_abs(j);
%     end
%     error_thirdOrder_abs(i,1) = 1/6*error_sum;
% end
% 
% error_thirdOrder_dyn = zonotope(interval(-error_thirdOrder_abs,error_thirdOrder_abs));

% %alternative
% %separate evaluation
% for i=1:length(T(:,1))
%     for j=1:length(T(1,:))
%         T_mid{i,j} = sparse(mid(T{i,j}));
%         T_rad{i,j} = sparse(rad(T{i,j}));
%     end
% end
% 
% 
% error_mid = 1/6*cubicMultiplication(Z_zono, T_mid);
% 
% %interval evaluation
% for i=1:length(T(:,1))
%     error_sum2 = 0;
%     for j=1:length(T(1,:))
%         error_tmp2(i,j) = dz_abs'*T_rad{i,j}*dz_abs;
%         error_sum2 = error_sum2 + error_tmp2(i,j) * dz_abs(j);
%     end
%     error_rad(i,1) = 1/6*error_sum2;
% end
% 
% 
% %combine results
% error_rad_zono = zonotope(interval(-error_rad, error_rad));
% error_thirdOrder_dyn = error_mid + error_rad_zono;

