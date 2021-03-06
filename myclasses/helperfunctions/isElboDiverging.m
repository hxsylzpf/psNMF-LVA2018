function [ isDiverging, varargout ] = isElboDiverging(...
        current_iteration, delta_cost, conv_crit, varargin)
%CHECKDIVERGENCEELBO Checks if the ELBO is diverging (i.e. value decreases)
%from last iteration.
%   Detailed explanation goes here

isDiverging = delta_cost < 0; % Negative slope

for i = 1:nargin-3
    varargout{i} = inf; %#ok<AGROW>
end

if isDiverging && abs(delta_cost) < conv_crit
    sw = sprintf('Soft-error: Lowerbound diverged in iteration %i, by %6.4e (relative err.).',...
                current_iteration,delta_cost);
    
    
    if nargin > 3 % Variable inputs
        
        for i = 1:nargin-3
            if varargin{i}{2} && current_iteration < varargin{i}{3}
                sw = sprintf('%s Starting to model %s now (iter. %i).',...
                                sw, varargin{i}{1},current_iteration);
                varargout{i} = current_iteration;
                break
            end
            
        end
    end
    warning(sw)
else
    % This indicates an error.
    assert(delta_cost>=0,' Lowerbound diverged by %12.4e!!', delta_cost)
end