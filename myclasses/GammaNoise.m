classdef GammaNoise < NoiseInterface
    
    properties
        hp_alpha = 1e-4;
        hp_beta = 1e-4;
        
        
        SSE;
        noise_value;
        noise_log_value;
        has_missing_values=false;
    end
    
    properties (Constant)
        supported_inference_methods = {'variational','sampling'};
        inference_default = 'variational';
    end
    
    properties (Access = private)
        est_beta;
        est_alpha;
    end
    
    methods
        
        function obj = GammaNoise(Xm, Rm, usr_hp_alpha, usr_hp_beta, inference_method)
            
            if isempty(Rm)
                obj.number_of_elements = numel(Xm);
            else
                obj.number_of_elements = nnz(Rm);
                obj.has_missing_values = ~(numel(Xm) == nnz(Rm));
            end
            
            obj.SST = sum(Xm(:).^2);
            
            if exist(usr_hp_beta,'var') && ~isempty(usr_hp_alpha) && ~isempty(usr_hp_beta)
                obj.hp_alpha = usr_hp_alpha;
                obj.hp_beta = usr_hp_beta;
            end
            
            obj.noise_value = obj.hp_alpha./obj.hp_beta;
            obj.noise_log_value = psi(obj.hp_alpha)-log(obj.hp_beta);
            
            
            obj.est_alpha = obj.hp_alpha;
            obj.est_beta = obj.hp_beta;
            
            if exist('inference_method','var')
                obj.inference_method = inference_method;
            else
                obj.inference_method = obj.inference_default;
            end
        end
        
        function sse = calcSSE(self,Xm, Rm, eFact, eFact2)
            [kr, kr2, krkr] = self.calcSufficientStats(eFact, eFact2);
            
            if self.has_missing_values
                sigA = eFact2{1}-eFact{1}.^2;
                sigB = kr2-kr.^2;
                M3 = sum(sum((Rm.*(eFact{1}*kr')).^2))+...
                    sum(sum(Rm.*((eFact{1}.^2)*sigB')))+...
                    sum(sum(Rm.*((sigA)*(kr.^2)')))+...
                    sum(sum(Rm.*(sigA*sigB')));
                
                self.SSE=(self.SST+M3-2*sum(sum(Xm.*(eFact{1}*kr'))));
            else
                self.SSE=(self.SST+sum(sum(krkr))-2*sum(sum(Xm.*(eFact{1}*kr'))));
            end
            assert(self.SSE >= 0)
            sse = self.SSE;
        end
        
        function updateNoise(self, Xm, Rm, eFact, eFact2)
            % Update error
            self.calcSSE(Xm,Rm,eFact,eFact2);
            
            %
            self.est_alpha = self.hp_alpha+self.number_of_elements/2;
            self.est_beta = self.hp_beta+self.SSE/2;
            
            if strcmpi(self.inference_method,'variational')
                self.noise_value = self.est_alpha ./ self.est_beta;
                self.noise_log_value = psi(self.est_alpha)-log(self.est_beta);
            elseif strcmpi(self.inference_method,'sampling')
                % Gamrnd samples from a gamma distribution with shape (alpha) and
                % scale (1./ beta)
                self.noise_value = gamrnd(self.est_alpha, 1./self.est_beta);
                self.noise_log_value = log(self.noise_value);
            end
            
            assert(isreal(self.noise_log_value))
        end
        
        function cost = calcCost(self)
            cost = 0.5*self.number_of_elements*(-log(2*pi)+self.noise_log_value)...
                -0.5*self.SSE*self.noise_value ...
                +self.calcPrior();
            
            if strcmpi(self.inference_method, 'variational')
                cost = cost+self.calcEntropy();
            end
            
        end
        
        function val = getExpFirstMoment(self)
            val = self.noise_value;
        end
        
        function val = getExpLogMoment(self)
            val = self.noise_log_value;
        end
        
        function val = getSSE(self)
            val = self.SSE;
        end
        
    end
    
    methods (Access = private)
        function [kr, kr2, krkr] = calcSufficientStats(self, eFact, eFact2)
            % Assumes the noise is on the first mode
            % Note that this assumes eFact2 to be an elementwise squared
            % expectation
            % It is not the same as <eFact'eFact> ... TODO...d
            D = size(eFact{1},2);
            kr=ones(1,D);
            if self.has_missing_values
                kr2 = ones(1,D);
                krkr = [];
            else
                kr2 = [];
                krkr=(eFact{1}'*eFact{1}).*(ones(D)-eye(D))+diag(sum(eFact2{1},1));
            end
            
            for i=2:length(eFact)
                kr=krprod(eFact{i}, kr);
                if self.has_missing_values
                    kr2=krprod(eFact2{i}, kr2);
                else
                    krkr=krkr.*((eFact{i}'*eFact{i}).*(ones(D)-eye(D))+diag(sum(eFact2{i},1)));
                end
            end
        end
        
        function entropy_contr = calcEntropy(self)
            entropy_contr =-log(self.est_beta)...
                +self.est_alpha...
                -(self.est_alpha-1)*psi(self.est_alpha)...
                +gammaln(self.est_alpha);
        end
        
        function prior_contr = calcPrior(self)
            prior_contr = -gammaln(self.hp_alpha)...
                +self.hp_alpha*log(self.hp_beta)...
                +(self.hp_alpha-1)*self.noise_log_value...
                -self.hp_beta*self.noise_value;
            
        end
    end
    
    
end