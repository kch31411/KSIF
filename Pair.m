classdef Pair < handle
    properties
        % TODO : 쓸데 없는 변수들은 지우고 바로바로 계산하도록
        idx_A;  % XXX : holding raw price data VS index only
        name_A;
        idx_B;
        name_B;
        cc;      % Cointegration Coefficient
        cor;    % correlation
        sp_mean;    % spread mean
        residual;   % spread - mean
        std_resid;  % standard deviation of residual
        count_A;
        count_B;
        mul_A = 10;  % 거래승수
        mul_B = 10;
        is_stationary = 0;
    end
    
    methods
        % get raw data and make object matrix
        function pairs = Pair(name, price, start_index, end_index)
            if nargin ~= 0      % Allow nargin == 0 syntax
                num_asset = size(name, 2);
                
                % waitbar 초기화
                count = 0;
                num_total_pairs = (num_asset * (num_asset-1)) / 2;
                wb = waitbar(0, 'Finding pairs..');
                
                pairs(1, num_total_pairs) = Pair;  % Preallocate object array
                
                for i=1:num_asset
                    for j=(i+1):num_asset;
                        cur_pair = Pair;
                        price_A = price(start_index:end_index, i);
                        price_B = price(start_index:end_index, j);
                        
                        cur_pair.idx_A = i;
                        cur_pair.idx_B = j;
                        cur_pair.name_A = name(i);
                        cur_pair.name_B = name(j);
                        
                        cov_pair = cov(price_A, price_B);
                        cur_pair.cc = cov_pair(2) / cov_pair(4);    % cov(A,B) / cov(B, B) = cov(A,B) / var(B)
                        
                        cur_pair.cor = corr(price_A, price_B);
                        
                        spread = price_A - cur_pair.cc * price_B;
                        cur_pair.sp_mean = mean(spread);
                        cur_pair.residual = spread - cur_pair.sp_mean;
                        cur_pair.std_resid = std(cur_pair.residual);
                        
                        % staionarity test
                        h1 = adftest(cur_pair.residual, 'alpha', 0.05, 'model', {'AR', 'ard', 'ts'});
                        if h1(1) == 1 && h1(2) == 1 && h1(3) == 1    % test for 3 models  XXX : really neccessary to test for 3 
                            h2 = lmctest(cur_pair.residual, 'alpha', 0.05);
                            if h2 == 0
                                cur_pair.is_stationary = 1;
                            end
                        end

                        % calculate number of contract
                        [cur_pair.cont_A, cur_pair.cont_B] = num_contracts(cur_pair, exp(price_A(end)), exp(price_B(end)));

                        % waitbar update
                        count = count + 1;
                        waitbar(count / num_total_pairs);
                        
                        pairs(count) = cur_pair;
                    end
                end
                close(wb);
            end
        end % constructor
        
        function [contract_A, contract_B] = num_contracts(this, price_A, price_B)
            % XXX : need verification
            cont_A = 1;
            cont_B = abs(this.cc * price_A * this.mul_A) / (price_B * this.mul_B);

            % XXX : how about using rats()
            if cont_B >= 1
                deci = cont_B - floor(cont_B);
                if deci > 0.8
                    cont_B = round(cont_B);
                elseif deci > 0.2
                    idx = 1;
                    while (deci*idx - floor(deci*idx) < 0.8) & (deci*idx - floor(deci*idx) > 0.2)
                        idx = idx + 1;
                    end

                    cont_B = round(cont_B * idx);
                    cont_A = idx;
                else
                    cont_B = floor(cont_B);
                end
            else
                cont_A = 1/cont_B;
                cont_B = 1;

                deci = cont_A - floor(cont_A);
                if deci > 0.8
                    cont_A = round(cont_A);
                elseif deci > 0.2
                    idx = 1;
                    while deci*idx - floor(deci*idx) < 0.8 & deci*idx - floor(deci*idx) > 0.2
                        idx = idx + 1;
                    end

                    cont_A = round(cont_A * idx);
                    cont_B = idx;
                else
                    cont_A = floor(cont_A);
                end
            end

            if this.cc > 0
                if this.residual(end) < 0 
                    cont_A = cont_A;
                    cont_B = -cont_B;
                else
                    cont_A = -cont_A;
                    cont_B = cont_B;
                end
            else
                if this.residual(end) > 0
                    cont_A = -cont_A;
                    cont_B = -cont_B;
                end
            end

            contract_A = cont_A;
            contract_B = cont_B;
        end
    end % methods
end

