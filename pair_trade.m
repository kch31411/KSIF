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
pairs = Pair(name, price);

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