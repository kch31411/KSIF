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
        cont_A;
        cont_B;
        mul_A = 10;  % 거래승수
        mul_B = 10;
        is_stationary = 0;
        entry = 0;  % Invest or not
        return_mean = 0;
        
        end_index;   % when finds pairs  XXX : naming..
        entry_index;
        
        observe_entry = 20;  % observation period whether invest or not
        observe_mean = 30;  % observation period close investment
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
                        cur_pair.end_index = end_index;
                        
                        price_A = price(start_index:end_index, i)';
                        price_B = price(start_index:end_index, j)';
                        
                        if (any(isnan(price_A)) || any(isnan(price_B)))
                            continue;       % if there is invalid data
                        end
                        
                        cur_pair.idx_A = i;
                        cur_pair.idx_B = j;
                        cur_pair.name_A = name(i);
                        cur_pair.name_A = cur_pair.name_A{1};
                        cur_pair.name_B = name(j);
                        cur_pair.name_B = cur_pair.name_B{1};
                        
                        cur_pair.cc = get_cc_ortho_reg_dist(price_A, price_B);
                        
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
                                
                                price_i = price(end_index:end, i)';
                                price_j = price(end_index:end, j)';  % XXX : much of useless operation
                                
                                spread2 = price_i - cur_pair.cc * price_j;
                                residual2 = spread2 - cur_pair.sp_mean;
                                
                                [cur_pair.entry, cur_pair.entry_index] = entry_decision(cur_pair, residual2);
                                
                                % mean return (makes profit)
                                if cur_pair.entry
                                    cur_pair.return_mean = mean_return_check(cur_pair, residual2);
                                end
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
        
        function ret = mean_return_check(this, residual)
            residual = residual(this.entry_index - this.end_index + 1:end);   % after entry
            
            entry_price = residual(1);
            epsilon = 0.01;
            
            ret = 0;
            i = 0;
            for v = residual
                if ~isnan(v) && ((entry_price < 0 && v + epsilon > 0) || ...
                        (entry_price >= 0 && v - epsilon < 0))
                    ret = 1;
                    return
                end
                
                i = i + 1;
                if i > this.observe_mean
                    return
                end
            end
        end
        
        function [decision, entry_index] = entry_decision(this, residual)
            sigma = this.std_resid;
            
            decision = 0;
            entry_index = -1;
            
            i = 0;
            for v = residual
                if ~isnan(v) && (v < (- 2 * sigma) || v > (2 * sigma))
                    decision = 1;
                    entry_index = this.end_index + i;
                    return
                end
                
                i = i + 1;
                if i > this.observe_entry
                    return
                end
            end
        end

    end % methods
end


function cc = get_cc_ortho_reg_dist(price1, price2)
    cov_pair = cov(price1, price2);
    var_x = cov_pair(1,1);
    var_y = cov_pair(2,2);
    cov_xy = cov_pair(1,2);
    cc = (var_y - var_x + sign(cov_xy) * sqrt((var_x - var_y)^2 + 4 * cov_xy^2)) / (2 * cov_xy);
end

function cc = get_cc_ortho_reg_area(price1, price2)
    cov_pair = cov(price1, price2);
    var_x = cov_pair(1,1);
    var_y = cov_pair(2,2);
    cov_xy = cov_pair(1,2);
    cc = sign(cov_xy) * sqrt(var_y / var_x);
end

function cc = get_cc_lin_reg(price1, price2)
    cov_pair = cov(price1, price2);
    cc = cov_pair(1, 2) / cov_pair(2, 2);    % cov(A,B) / cov(B, B) = cov(A,B) / var(B)
end

function cc = get_cc_autocor(price1, price2)
    autocor = @(cc) get_autocor(get_residual(price1, price2, cc));
    cc = fminbnd(autocor, -4, 4);
end

function autocor = get_autocor(res)
    autocor = sum(res(1:end-1).*res(2:end))/sum(res(2:end).^2);
end
function res = get_residual(price1, price2, cc)
    spread = price1 - cc * price2;
    sp_mean = mean(spread);
    res = spread - sp_mean;
end

