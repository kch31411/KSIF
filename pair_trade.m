tic;   % elapsed time
clc; clear; close all;

%% Constant declare
% ex) pair verification period, invest entrance criteria 등등
FIND_PAIR_PERIOD = 360;     % 1.5 year

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

% Period set up
get_date_from_user = input('기간 직접 입력 : y / 기본값(가장 최근날짜부터) 사용 : n)  [n]: ', 's');
if get_date_from_user == 'y'
    end_date = input('종료일자 (yyyy-mm-dd): ', 's');
    end_date = datenum(end_date, 'yyyy-mm-dd');
    period = input('관찰기간: ');
else
    end_date = date(end);    % last date
    period = FIND_PAIR_PERIOD;
end

% Find range of array
end_index = find(date==end_date, 1);
if isempty(end_index)
    end_index = num_date;
    display('Warning : invalid end_date');
end
start_index = end_index - period + 1;
if start_index <= 0
    start_index = 1;
    display('Warning : not enough input data (start_date)');
end

pairs = Pair(name, price, start_index, end_index);

display(sprintf('asset A\tvs.\tasset B\tcorrelation\tcointegration\tspread mean\tcontraction A\tcontraction B\n'));
for pair=pairs
    if pair.is_stationary
        tmp_text = [pair.name_A '\tvs.\t' pair.name_B '\t%3.1f%%\t%10.3f\t%10.3f\t%d\t%d'];

        display(sprintf(tmp_text, 100 * pair.cor, pair.cc, pair.sp_mean, pair.cont_A, pair.cont_B));

        title_plot = [pair.name_A ' vs. ' pair.name_B];
        plot_spread(x2mdate(date(start_index:end_index), 0), pair.residual, title_plot, 100 * pair.cor, pair.cc, pair.cont_A, pair.cont_B); 
        tmp_mvavg = tsmovavg(pair.residual','s',5);
        plot_spread(x2mdate(date(start_index+4:end_index)), tmp_mvavg(5:end), title_plot, 100 * pair.cor, pair.cc, pair.cont_A, pair.cont_B); 
    end
end


%%

toc