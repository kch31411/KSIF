classdef Pair < handle
    properties
        % TODO : 쓸데 없는 변수들은 지우고 바로바로 계산하도록
        idx_A;
        name_A;
        idx_B;
        name_B;
        cc;
        corr;    % correlation
        sp_mean;    % spread mean
        residual;   % spread - mean
        std_resid;  % standard deviation of residual
        count_A;
        count_B;
        mul_A = 10;  % 거래승수
        mul_B = 10;
    end
    
    methods
        function this = Pair()
            this.idx_A = 10000000000;
        end % constructor
        
        function r = sampleMethod(this)
            r = 0;
        end
    end % methods
end

