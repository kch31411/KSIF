classdef Pair < handle
    properties
        % TODO : ���� ���� �������� ����� �ٷιٷ� ����ϵ���
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
        mul_A = 10;  % �ŷ��¼�
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

