function [Xout, Yout] = sct_moco_spline(fname_mat, varargin)
% sct_moco_spline(fname_mat)
% sct_moco_spline(fname_mat, fname_log, abrupt_motion_index, smoothness )
%
% sct_moco_spline('mat.*') --> calls an interactive GUI for selecting index of abrupt
% motion and smoothness coefficient
% sct_moco_spline('mat.*','log.txt',[51 102],1)


if ~isempty(varargin), log_spline = varargin{1}; else log_spline = 'log_sct_moco_spline'; end
if length(varargin)>1, ind_ab = varargin{2}; else  ind_ab = -1; end
if length(varargin)>2, smoothness = varargin{3}; else smoothness = -1; end


j_disp(log_spline,['\nSmoothing Patient Motion...'])
% LOAD MATRIX
[list, path]=sct_tools_ls(fname_mat);

Z_index=double(round(cellfun(@(x) cell2mat(textscan(x,'%*[mat.T]%*u%*[_Z]%u%*[.txt]')),list)));
T=cellfun(@(x) cell2mat(textscan(x,'%*[mat.T]%u%*[_Z]%*u%*[.txt]')),list); T=single(T);
j_progress('loading matrix...')
for imat=1:length(list), j_progress(imat/length(list)); M_tmp{imat}=load([path{imat} list{imat}]); X(imat)=M_tmp{imat}(1,4); Y(imat)=M_tmp{imat}(2,4); end
j_progress('elapsed')

color=jet(max(Z_index));
% Plot subject movement
figure(28); hold off;
for iZ=unique(Z_index)
    subplot(2,1,1); plot(T(Z_index==iZ),X(Z_index==iZ),'+','Color',color(iZ,:)); ylim([min(X)-0.5 max(X)+0.5]); hold on
    if iZ==1, hold off; end
    subplot(2,1,2); plot(T(Z_index==iZ),Y(Z_index==iZ),'+','Color',color(iZ,:)); ylim([min(Y)-0.5 max(Y)+0.5]); hold on
    
   % TZ=T(Z_index==iZ);
    % abrupt motion detection
    %installPottslab
%     u=minL1Potts(Y(Z_index==iZ), 10, 'samples',T(Z_index==iZ));
%     v=minL1Potts(X(Z_index==iZ), 10, 'samples',T(Z_index==iZ));
%[ind_ab TZ(find(diff(u))) TZ(find(diff(v)))];
end
drawnow;

%% Get abrupt motion volume #
if min(ind_ab)<0
        ind_ab = inputdlg('Enter space-separated numbers:',...
            'Volume# before abrupt motion (starting at 1)',[1 150]);
        if isempty(ind_ab), ind_ab=[]; else ind_ab = str2num(ind_ab{:}); end
        j_disp(log_spline,['Abrupt motion on Volume #: ' num2str(ind_ab)])
end

% search for abrupt motion automatically using 1st slice in both Y
% and X
Y1 = Y(Z_index==1);
abb = diff(Y1)>1;
ind_abY = double([0 find([diff(~abb) 0 0]==1) max(T)]);
X1 = X(Z_index==1);
abb = diff(X1)>1;
% combine both with precaution --> no abrupt motion closer than 2
% volumes
ind_abX = find([diff(~abb) 0 0]==1);
ind_ab = unique([ind_abX ind_abY ind_ab]);
ind_ab([true ~(diff(ind_ab)<3)]);
%         % abrupt separetly
%         ind_abX = double([0 find([diff(~abb) 0 0]==1) max(T)]);
%         ind_ab = {ind_abX, ind_abY};

if ~iscell(ind_ab)
    ind_ab(ind_ab>=max(T) | ind_ab<=1)=[];
    ind_ab=double([0 ind_ab max(T)]);
end

ind_ab(ind_ab>=max(T) | ind_ab<=1)=[];
ind_ab=double([0 ind_ab(:)' max(T)]);




%% GENERATE SPLINE
if smoothness<0
    msgbox({'Use the slider (figure 28, bottom) to calibrate the smoothness of the regularization along time' 'Press any key when are done..'})
    
    hsl = uicontrol('Style','slider','Min',-10,'Max',0,...
        'SliderStep',[1 1]./10,'Value',-2,...
        'Position',[20 20 200 20]);
    set(hsl,'Callback',@(hObject,eventdata) GenerateSplines(X,Y,T,Z_index,ind_ab,10^(get(hObject,'Value')),color ))
    
    pause
    smoothness = 10000*10^(get(hsl,'Value'));
end
j_disp(log_spline,['Smooth using smoothness of ' num2str(smoothness) '...'])
[Xout, Yout]=GenerateSplines(X,Y,T,Z_index,ind_ab,smoothness/10000,color);
j_disp(log_spline,['...done!'])
%% SAVE MATRIX
j_progress('\nSave Matrix...')
% move old matrix
if ~exist([path 'old'],'dir'); mkdir([path 'old']); end
unix(['mv ' fname_mat ' ' path 'old/'])

% create new list
for iT=1:max(T)
    for iZ=unique(Z_index)
        mat_name=['mat.T' num2str(iT) '_Z' num2str(iZ) '.txt'];
        % update matrix
        M=diag([1 1 1 1]);
        M(1,4)=Xout(iZ,iT); M(2,4)=Yout(iZ,iT);
        % write matrix
        fid = fopen([path mat_name],'w');
        fprintf(fid,'%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n',[M(1,1:4), M(2,1:4), M(3,1:4), M(4,1:4)]);
        fclose(fid);
        
    end
end


function [Xout,Yout]=GenerateSplines(X,Y,T,Z_index,ind_ab,smoothness,color)
if iscell(ind_ab), ind_abX = ind_ab{1}; ind_abY = ind_ab{2}; 
else, ind_abX = ind_ab; ind_abY = ind_ab; 
end
figure(28), hold off,
for iZ=unique(Z_index)
    Xtmp=X(Z_index==iZ); Ytmp=Y(Z_index==iZ); Ttmp=T(Z_index==iZ);
    Xout(iZ,:) = spline_piecewise(ind_abX,Ttmp,Xtmp,smoothness);
    Yout(iZ,:) = spline_piecewise(ind_abY,Ttmp,Ytmp,smoothness);
    % plot splines
    Ttotal=1:max(T);
    subplot(2,1,1); plot(T(Z_index==iZ),X(Z_index==iZ),'+','Color',color(iZ,:)); ylim([min(X)-0.5 max(X)+0.5]); hold on
    subplot(2,1,1); plot(Ttotal,Xout(iZ,:),'-','Color',color(iZ,:));  ylim([min(X)-0.5 max(X)+0.5]); legend('raw moco', 'smooth moco', 'Location', 'NorthEast' ); grid on; ylabel( 'X Displacement (mm)' ); xlabel('volume #');
    if iZ==1, hold off; end
    subplot(2,1,2); plot(T(Z_index==iZ),Y(Z_index==iZ),'+','Color',color(iZ,:)); ylim([min(Y)-0.5 max(Y)+0.5]); hold on
    subplot(2,1,2); plot(Ttotal,Yout(iZ,:),'-','Color',color(iZ,:));  ylim([min(Y)-0.5 max(Y)+0.5]); legend('raw moco', 'smooth moco', 'Location', 'NorthEast' ); grid on; ylabel( 'Y Displacement (mm)' ); xlabel('volume #');
end
drawnow;


function Xout = spline_piecewise(ind_ab,Ttmp,Xtmp,smoothness)
for iab=2:length(ind_ab)
    disp(['Generate motion splines...'])
    Tpiece=ind_ab(iab-1)+1:ind_ab(iab);
    
    index=Ttmp>ind_ab(iab-1) & Ttmp<=ind_ab(iab);% Piece index
    if length(find(index))>1
        Xout(1,Tpiece)=spline(Ttmp(index),Xtmp(index),smoothness,Tpiece);
    else
        [~,closestT_l]=min(abs(Ttmp-mean([ind_ab(iab), ind_ab(iab-1)])));
        Xout(1,Tpiece)=Xtmp(closestT_l);
    end
end


function M_motion_t_smooth = spline(T,M_motion_t,smoothness,Tout)
disp(['Smooth using smoothness of ' num2str(10000*smoothness) '...'])
 M_motion_t_smooth=smoothn_x(T,M_motion_t,Tout,10000*smoothness,1);


% %% Fit: 'sct_moco_spline'.
% [xData, yData] = prepareCurveData( T, M_motion_t );
% % Set up fittype and options.
% ft = fittype( 'smoothingspline' );
% opts = fitoptions( ft );
% opts.SmoothingParam = smoothness;
% opts.Robust='Bisquare';
% 
% % Fit model to data.
% [fitresult, gof] = fit( xData, yData, ft, opts );
% M_motion_t_smooth = feval(fitresult,Tout);
% % 
% 
% 
% 
