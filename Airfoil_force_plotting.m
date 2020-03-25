%Plotting for Wind Tunnel Airfoil Force Data
%Sean Patrick Devey
%3_10_20
%% TO DO:
% add capability to plot bias corrected data along with uncorrected
% also capability to plot tunnel corrected with uncorrected
% what the heck is up with the drag data here?
%% Description: plots data that has been processed by the Airfoil_force_process.m script
%reads in processed data files generated by Airfoil_force_process.m script, generates plots
%Requires excel data files
%reference data files are good to have as well, should be in .xlsx with columns: aoa, cx
%Units are assumed to be SI

clear; clc;
% close all;
%keep figures where they are for next run
for m=1:length(findobj('type','figure'))
    figure(m)
    clf('reset');
end

%info for uncertainty analysis
prob = 0.05; %prob used to find confidence interval for error bars 0.05 => 95% confidence interval
force_bias = .145;%0.125+0.02; %(N) estimated bias in load cell force measurements (resolution + drift)
% force_bias = 2.9; %measurement uncertainty from manufacturer
%force_bias = 1 N ish near highest load case? need to investigate more to find better estimate of error as function of Fx, Fy, resultant angle, or Tx, Ty?
moment_bias = 0.0013+0.005; %(Nm) estimated bias in load cell moment measurements

span = 11.8125*2.54/100; %airfoil span in meters new one is at 11+7/8, old at 11+13/16
chord = 8*2.54/100; %airfoil chord in meters
mu = 1.81*10^-5; %dynamic viscosity (kg/(ms))
%% import reference data from file locations
% reference data
ref_data_loc = 'C:\Users\seanp\Documents\Box Sync\Everything\Documents\Research\Fall 2018 - Summer 2019\2019 wind tunnel experiment\Data\NACA 0012 reference data\formatted reference data';
ref_data_loc_cd = strcat(ref_data_loc,'\NACA0012 RE360000 cd_full sandia78.xlsx');
ref_data_loc_cl = strcat(ref_data_loc,'\NACA0012 RE360000 cl sandia78.xlsx');
ref_data_loc_cm = strcat(ref_data_loc,'\NACA0012 RE360000 cm sandia78.xlsx');
data_ref_cd = xlsread(ref_data_loc_cd);
data_ref_cl = xlsread(ref_data_loc_cl);
data_ref_cm = xlsread(ref_data_loc_cm);
%% define data folder for experimental data
% data_folder = pwd; %set data folder as current folder (could make this something different if that becomes more conveinent later
data_folder = 'C:\Users\seanp\Documents\Box Sync\Everything\Documents\Research\Fall 2019 - Spring 2020\Data\post-processing';
subfolders_name = GetSubDirsFirstLevelOnly(data_folder);
[~,num_subfolders] = size(subfolders_name);
%% define what data to read
% biasCorr = 0; %   1 = apply
tunnelCorr = 0; % 0 = don't
%% loop through different corrections
for biasCorr = [1,0]
% for tunnelCorr = [1,0]
if biasCorr == 0 %logic for selecting from which sheet to read
    if tunnelCorr == 0
        sheet_label = "no corrections";
    else
        sheet_label = "tunnelCorr only";
    end
else % biasCorr == 1
    if tunnelCorr == 0
        sheet_label = "biasCorr only";
    else
        sheet_label = "biasCorr & tunnelCorr";
    end
end
%% cycle through each subfolder
for n = 1:num_subfolders
    clear data
    if ~isempty(dir(fullfile(data_folder,subfolders_name{n},'*.xlsx')))
        data_files = dir(fullfile(data_folder,subfolders_name{n},'*.xlsx'));   %get list of each file in folder
        data(:,:,1) = readmatrix(fullfile(data_folder,subfolders_name{n},data_files(1).name),'Sheet',sheet_label,'OutputType','double');
%         legend_index(i) = n;
    else
        %             error(sprintf(strcat("There don't appear to be any files with a *.xlsx extension in folder: \n",fullfile(data_folder,subfolders_name{n}),"\n(The files can't be in a subdirectory)")));
        warning = sprintf("%s\n",'There do not appear to be any files with a *.xlsx extension in folder:',fullfile(data_folder,subfolders_name{n}),"(The files can't be in a subdirectory)")
%         p(n) = [];%plot([2,1],[1,2],'HandleVisibility','off');
        continue
    end
    for k = 2:length(data_files)    %read each file into a data matrix
        data_current = readmatrix(fullfile(data_folder,subfolders_name{n},data_files(k).name),'OutputType','double');
        if size(data_current)==size(data(:,:,k-1))  %make sure the files are all the same size. Eventually the fix for this could be automated.
            data(:,:,k) = data_current;
        else
            error(strcat('this file is the wrong size! Check the size of file number: ',num2str(k),' or all the ones before it. (sorted alphabetically?)'));
        end
    end
    [~,filename_only,~] = fileparts(fullfile(data_folder,subfolders_name{n},data_files(1).name));
    %% determine airfoil type
    control = strfind(filename_only,'ontrol');
    microflap = strfind(filename_only,'icroflaps');
    trip = strfind(filename_only,'trip');
    if ~isempty(control)
        if ~isempty(microflap)
            error(strcat('this filename says control and microflap in it? Check file: ',filename_only))
        end
        if ~isempty(trip)
            name = "control, trip";
            marker = 'rx';
        else
            name = "control";
            marker = 'r*';
        end
    end
    if ~isempty(microflap)
        if ~isempty(control)
            error(strcat('this filename says control and microflap in it? Check file: ',filename_only))
        end
        if ~isempty(trip)
            name = "microflaps, trip";
            marker = 'k>';
        else
            name = "microflaps";
            marker = 'k<';
        end
    end
    [row,col,run] = size(data);
    %% find mean speed, Re. - check that all runs are at the same speed
    mean_speed = mean(mean(data(:,1,:))); % average of all speeds measured (m/s_
    mean_rho = mean(mean(data(:,2,:))); % average of all densities measured (kg/m3)
    mean_q = .5*mean_rho*mean_speed^2; % average dynamic pressure (Pa) for all runs
    speed_tol = 2; %tolerance of drift in speed measurement (m/s)
    if (max(data(:,1,:)) >= (mean_speed+speed_tol)) %make sure there isn't some data at a different speed getting mixed in
        error('the speed somewhere is too high')
    end
    if (min(data(:,1,:)) <= (mean_speed-speed_tol))
        error('the speed somewhere is too low') %not very helpful error messages, but will prevent from being dumb
    end
    Re = round(mean_speed*mean_rho*chord/mu,-4); %round RE to nearest 10,000
    %% Average all runs, calculate uncertainty
    %I'm pretty sure that the bias will end up being more complicated than this
    %perhaps for bias I should be taking Fx, Fy error from biasCorrection and convert
    B_f = nondim_force(force_bias,mean_q,chord,span); %bias of force measures
    B_m = nondim_mom(moment_bias,mean_q,chord,span); %bias of moment measures
    Bias = [0,0,0,B_f,B_f,B_m];
    t_score = tcdf(prob,run-1);
    u = zeros(row,col-1);
    u_fix=u;
    data_mean = zeros(row,col-1);
    %     Bias = zeros(col,1);
    for i=1:row
        for j=1:col-1
            data_mean(i,j) = mean(data(i,j,1:run));
            sigma = std(data(i,j,1:run));
            P95 = sigma*t_score/sqrt(run); %calc 95% confidence interval
            %             Bias(j) = 0.01*data_mean(i,j); %apply some sort of bias thing. This currently says that bias is 10% of measurement, which is not really true.
            u(i,j) = sqrt(Bias(j)^2+P95^2);
        end
    end
    fig_count=0;
    %% plot mean of adjusted v. reference coefficients
    % {
    % for j=4:col-1 %cycle through cd,cl,cm
    col_name = ["speed (m/s)","density (kg/m3)","aoa (deg)","c_d","c_l","c_{m_{c/4}}"]; %names of columns for coef matrixes
    ylimits = [ [0, .4]; [0, 1]; [-0.1,0.04] ]; %sizes of coef plots
    legend_location = ["northwest","southeast","northeast"];
    for j=4:6
        %legend('off')
        fig_count=fig_count+1;
        figure(fig_count);
        %     p1 = errorbar(data_mean(:,2),data_mean(:,j)*1.154,u(:,j),'ro','DisplayName','control');
        p(n) = errorbar(data_mean(:,3),data_mean(:,j),u(:,j),marker,'DisplayName',name);
        hold on
        if j==4 %if plotting cd
            p8 = plot(data_ref_cd(:,1),data_ref_cd(:,2),'bo','DisplayName',"Sheldahl '78^3");
            cdo = 0.0044 + 0.018*Re^(-0.15); %estimate for cdo for 10^6<RE<3*10^7 given in McCroskey "Critical Assessment of Wind Tunnel Results of NACA 0012"
            p9 = plot(0,cdo,'kd','DisplayName',"c_{d0} McCroskey '88^4");
            %p4 = plot([],'HandleVisibility','off'); %use this to avoid error in legend if not plotting cdo
        elseif j==5 %if plotting cl
            p8 = plot(data_ref_cl(:,1),data_ref_cl(:,2),'bo','DisplayName',"Sheldahl '78^3");
            cla = 0.1025 + 0.00485*log(Re/10^6); %empirical curve fit for lift curve slope (/deg) prestall for NACA 0012 +-2% from McCroskey "Critical Assement..."
            x=linspace(0,10);
            y=x*cla;
            p9 = plot(x,y,'k:','DisplayName',"c_{l\alpha} McCroskey '88^4");
            %         p4 = plot([],'HandleVisibility','off'); %use this to avoid error in legend if not plotting cla
        elseif j==6 %if plotting cm
            p8 = plot(data_ref_cm(:,1),data_ref_cm(:,3),'bo','DisplayName','ref. data (up sweep)');
            p9 = plot(data_ref_cm(:,1),data_ref_cm(:,2),'b+','DisplayName','ref. data (down sweep)');
        end
        xlabel('\alpha (deg)')
        xlim([0,25])
        ylabel(col_name(j))
        ylim(ylimits(j-3,:))
        %         axis = gca;
        n_new=n;
        h=1;
        while (h <= n_new) %remove empty graphics parts of p variable to allow legend call to go through
            if ~isgraphics(p(h))
                p(h) = [];
                n_new=n_new-1;
                p_start=h+1;
            end
            h=h+1;
        end      
        legend(gca,[p(p_start:end) p8 p9],'Location',legend_location(j-3))
%         legend(gca,'Location',legend_location(j-3))
        title(strcat(sheet_label,' U = ',num2str(mean_speed,3),' m/s ',' Re = ',num2str(Re,3)))
        %     % Set axes font
        %     ax = axes('Parent',fig);
    end
end
end
function [subDirsNames] = GetSubDirsFirstLevelOnly(parentDir)
% Get a list of all files and folders in this folder.
%taken from matlab forums
files    = dir(parentDir);
names    = {files.name};
% Get a logical vector that tells which is a directory.
dirFlags = [files.isdir] & ~strcmp(names, '.') & ~strcmp(names, '..');
% Extract only those that are directories.
subDirsNames = names(dirFlags);
end
function [coef] = nondim_force(force,q,chord,span)
%Turns force into section coefficient
%   D -> c_d
%force = raw force
%chord = airfoil chord
%span = airfoil span
%q = dynamic pressure
coef = force/(q*chord*span);
end
function [coef] = nondim_mom(moment,q,chord,span)
%Turns moment into section coefficient
%   M_z -> c_m
%moment = some moment
%chord = airfoil chord
%q = dynamic pressure
coef = moment/(q*span*chord^2);
end