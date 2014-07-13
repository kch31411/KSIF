tic;   % elapsed time
clc; clear; close all;

%% Constant declare
% ex) pair verification period, invest entrance criteria 등등

%% Read input data
% fnDataGuide
[ndata, text, alldata] = xlsread('future_price.xlsx');

date = datenum(text(15:end,1), 'yyyy-mm-dd');

name = text(10, 2:end);
% 종목이름 F 연결선물지수 -> 종목이름
name = arrayfun(@(x) textscan(x{1}, '%s', 'delimiter', ' '), name, 'UniformOutput', false);   % @(x) strsplit(x{1}) in current version of matlab 
name = arrayfun(@(x) x{1}{1}{1}, name, 'UniformOutput', false);

price = ndata(8:end,:);
price = log(price);    % conver to log scale

% data validation check
num_date = size(date, 1);
assert(num_date == size(price, 1), 'ERROR : date size does not match');
num_asset = size(name, 2);
assert(num_asset == size(price, 2), 'ERROR : asset size does not match');

%% Finding pair

[num_row num_col] = size(ndata);
num_asset = num_col-1;
num_insmpl = num_row;

cc_pairs = zeros(num_asset-1, num_asset);
pairs_stationary = zeros(num_asset-1, num_asset);

wb = waitbar(0,'Please wait...');
idx_pairs = 1;
for idx_A=1:num_asset
    for idx_B=1:num_asset;
        
        if idx_A < idx_B
            
            cov_pairs = cov(ndata(1:num_insmpl, 1+idx_A), ndata(1:num_insmpl, 1+idx_B));
            var_pairs = var(ndata(1:num_insmpl, 1+idx_B));
            cc_pairs(idx_A, idx_B) = cov_pairs(2)/var_pairs;
            
            corr_pairs = corr(ndata(1:num_insmpl, 1+idx_A), ndata(1:num_insmpl, 1+idx_B));
            spread = ndata(1:num_insmpl,1+idx_A)-ndata(1:num_insmpl,1+idx_B)*cc_pairs(idx_A,idx_B);
            sp_mean = mean(spread);
            resid = spread-sp_mean;
            std_resid=std(resid);
            
            h1 = adftest(resid, 'alpha', 0.05, 'model', {'AR', 'ard', 'ts'});

            if h1(1) == 1 && h1(2) == 1 && h1(3) == 1
            
                h2 = lmctest(resid, 'alpha', 0.05);
                
                if h2 == 0
                    pairs_stationary(idx_A, idx_B) = 1;

                    PAIRS(idx_pairs).idx_A = idx_A;
                    PAIRS(idx_pairs).idx_B = idx_B;
                    PAIRS(idx_pairs).cc = cc_pairs(idx_A, idx_B);
                    PAIRS(idx_pairs).corr = corr_pairs;
                    PAIRS(idx_pairs).sp_mean = sp_mean;
                    PAIRS(idx_pairs).residual = resid;
                    PAIRS(idx_pairs).std_resid = std_resid ;

                    % 국내선물에서는 아래의 값들이 pair마다 일정함

                    PAIRS(idx_pairs).mul_A = 10;
                    PAIRS(idx_pairs).mul_B = 10;
                    %PAIRS(idx_pairs).deposit_A = data_info{idx_assetA, 6};
                    %PAIRS(idx_pairs).deposit_B = data_info{idx_assetB, 6};

                    % deposit=증거금 /  선물 한 계약 사려면 가지고 있어야 하는 금액
                    % nominal = 계약수*승수*가격을 1:1.5로 맞춰줘야해
                    
                    % 계약수 구하는 함수를 사용하여 계약수 계산
                    [PAIRS(idx_pairs).cont_A, PAIRS(idx_pairs).cont_B] = num_contracts(PAIRS(idx_pairs).cc, exp(ndata(num_insmpl, 1+idx_A)), PAIRS(idx_pairs).mul_A, exp(ndata(num_insmpl, 1+idx_B)), PAIRS(idx_pairs).mul_B, resid(num_insmpl, 1));
                    
                    % Regression으로 speed 구하기
                    regressors = [ones(length(spread) - 1, 1) spread(1:num_insmpl-1)];
                    [coefficients, intervals, residuals] = ...
                    regress(diff(spread), regressors);
                    dt    = 1;  % time increment = 1 day
                    PAIRS(idx_pairs).speed = -coefficients(2)/dt;
                    level = -coefficients(1)/coefficients(2);
                    sigma =  std(residuals)/sqrt(dt);
                                 
                        for aaa = 100:num_row;
                        regressors = [ones(aaa - 1, 1) spread(1:aaa-1)];
                        [coefficients, intervals, residuals] = ...
                        regress(diff(spread(1:aaa)), regressors);
                        dt    = 1;  % time increment = 1 day
                        kappa(aaa) = -coefficients(2)/dt;   
                        end
                        
                       %  xlswrite(strcat('kappa',num2str(idx_pairs)),kappa')
                        xlswrite(strcat('spread_',num2str(idx_pairs)),resid)
                       
                        
                     idx_pairs = idx_pairs+1;

                else
                    pairs_stationary(idx_A, idx_B) = 0;
                end
            else
                pairs_stationary(idx_A, idx_B) = 0;
            end
        end
        waitbar(((idx_A - 1) * num_asset + idx_B) / (num_asset * num_asset));
    end
end
close(wb);

%%
num_pairs = nnz(pairs_stationary);
disp_matrix = cell(num_pairs+1,9);

% disp_matrix(1, :) = {'assetA', 'vs.', 'assetB', 'corr', 'cc', 'sp. mean','std_resid', 'contract A', 'contract B'};
display(sprintf('asset A\tvs.\tasset B\tcorrelation\tcointegration\tspread mean\tcontraction A\tcontraction B\tspeed\n'));
for idx=1:num_pairs
    % pos_plot = rem(idx,6);

    tmp_text = [text{1,PAIRS(idx).idx_A} '\tvs.\t' text{1,PAIRS(idx).idx_B} '\t%3.1f%%\t%10.3f\t%10.3f\t%d\t%d\t%d'];
    
    display(sprintf(tmp_text, 100*PAIRS(idx).corr, PAIRS(idx).cc, PAIRS(idx).sp_mean, PAIRS(idx).cont_A, PAIRS(idx).cont_B, PAIRS(idx).speed));
    
    title_plot = [text{1,PAIRS(idx).idx_A} ' vs. ' text{1,PAIRS(idx).idx_B}];
    plot_spread(ndata(1:num_insmpl, 1)+693960, PAIRS(idx).residual, title_plot, 100*PAIRS(idx).corr, PAIRS(idx).cc, PAIRS(idx).cont_A, PAIRS(idx).cont_B); 
    tmp_mvavg = tsmovavg(PAIRS(idx).residual','s',5);
    plot_spread(ndata(5:num_insmpl, 1)+693960, tmp_mvavg(5:num_insmpl), title_plot, 100*PAIRS(idx).corr, PAIRS(idx).cc, PAIRS(idx).cont_A, PAIRS(idx).cont_B); 
end


%%

toc