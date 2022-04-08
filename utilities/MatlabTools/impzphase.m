classdef impzphase < handle
    properties
        headstr
        data
        x
        xp
        y
        yp
        z
        dgam
        delta
        
        histz
        histdgam
        histdelta
        
        %slice valuable
        %--------------
        sliz
        slinp
        sliI
        slienx
        slieny
        slidEoE
        slidE
        slix0
        sliy0
        slidelta
        
        %for setting the axis range
        %--------------------------
        xlim
        ylim
        
        %for data save
        %-------------
        filename
        
    end
    methods
        function obj=impzphase(filenum,path)
            %usage:
            % impzphase('1000')
            % or impzphase('1000','absPath')
            % read the phase space
            %---------------------
            
            
            if nargin==1
                path='.';                
            end
            phasefile = [path '/fort.' num2str(filenum)];   %fort.1000 
            slicefile = [path '/fort.1' num2str(filenum)];  %fort.11000
                            
            obj.filename=num2str(filenum);
            
            tmp1 = importdata(phasefile,' ',1);
            obj.headstr = tmp1.textdata;
            obj.data    = tmp1.data;
            obj.x       = obj.data(:,1);
            obj.xp      = obj.data(:,2);
            obj.y       = obj.data(:,3);
            obj.yp      = obj.data(:,4);
            obj.z       = obj.data(:,5);
            obj.dgam    = obj.data(:,6);
            
            dim = size(obj.data);
            if dim(2) == 7
                obj.delta   = obj.data(:,7);
            end
            
            obj.histz   = obj.gethist(obj.z);
            obj.histdgam= obj.gethist(obj.dgam);
            obj.histdelta= obj.gethist(obj.delta);
            
            % read the slice enformation
            %---------------------------
            tmp2 = importdata(slicefile);
            obj.sliz       = tmp2(:,1);
            obj.sliI       = tmp2(:,3);
            obj.slienx     = tmp2(:,4);
            obj.slieny     = tmp2(:,5);
            obj.slidEoE    = tmp2(:,6); %not sure what is it
            obj.slidE      = tmp2(:,7);
            obj.slix0      = tmp2(:,8);
            obj.sliy0      = tmp2(:,9);  
            obj.slidelta   = tmp2(:,10);  
            % set default axisrange 
            obj.xlim = [];
            obj.ylim = [];
            
        end           
        
        % group plot 
        % ========================
        function phaseheatgroup(obj)
            subplot(3,3,1)
            obj.phaseheat(12)
            subplot(3,3,2)
            obj.phaseheat(34)
            subplot(3,3,3)
            obj.phaseheat(13)
            subplot(3,3,4)
            obj.phaseheat(51)
            subplot(3,3,5)
            obj.phaseheat(52)
            subplot(3,3,6)
            obj.phaseheat(561)           
            subplot(3,3,7)
            obj.phaseheat(53)
            subplot(3,3,8)
            obj.phaseheat(54)
            subplot(3,3,9)
            obj.phaseheat(562)
            set(gcf,'unit','normalized','position',[0,0,1,1]);
        end
        
        function sligroup(obj)
            subplot(2,3,1)
            obj.plotsli('I')       
            
            subplot(2,3,2)
            plot(obj.sliz*1e3,obj.slienx*1e6)
            hold on
            plot(obj.sliz*1e3,obj.slieny*1e6)
            legend('enx','eny')
            xlabel('z (mm)')
            ylabel('slice norm. emit. (mm mrad)')
                      
            subplot(2,3,3)
            obj.plotsli('delta')           
            subplot(2,3,4)
            obj.plotsli('x0')            
            subplot(2,3,5)
            obj.plotsli('y0')           
            subplot(2,3,6)
            obj.plotsli('dE')    
            
            set(gcf,'unit','normalized','position',[0,0,1,1]);
        end          
        
        % single plot
        % =============================
        function phaseheat(obj,option,col2)            
            if nargin==2
                % if two input paras
                if option==561
                    % use x,y, convenient for change units
                    x=obj.z*1e6;
                    y=obj.dgam;  
                    label1 = 'z (\mum)';
                    label2 = '\Delta\gamma'; 
                elseif option==562
                    % use x,y, convenient for change units
                    x=obj.z*1e6;
                    y=obj.delta;  
                    label1 = 'z (\mum)';
                    label2 = '\delta';                    
                elseif option==51
                    x=obj.z*1e3;
                    y=obj.x*1e3;
                    label1 = 'z (mm)';
                    label2 = 'x (mm)';
                elseif option==52
                    x=obj.z*1e3;
                    y=obj.xp;
                    label1 = 'z (mm)';
                    label2 = 'x\prime';                    
                elseif option==53
                    x=obj.z*1e3;
                    y=obj.y*1e3;
                    label1 = 'z (mm)';
                    label2 = 'y (mm)'; 
                elseif option==54
                    x=obj.z*1e3;
                    y=obj.yp;
                    label1 = 'z (mm)';
                    label2 = 'y\prime';                    
                elseif option==13
                    x=obj.x*1e3;
                    y=obj.y*1e3;
                    label1 = 'x (mm)';
                    label2 = 'y (mm)';  
                elseif option==12
                    x=obj.x*1e3;
                    y=obj.xp;
                    label1 = 'x (mm)';
                    label2 = 'x\prime';  
                elseif option==34
                    x=obj.y*1e3;
                    y=obj.yp;
                    label1 = 'y (mm)';
                    label2 = 'y\prime';                                 
                end
            elseif nargin==3
                x=option;  %option is col1 now
                y=col2;
                % label set by outside
                label1='x';  
                label2='y';
%             elseif nargin                  
            end           
            %--------------------
            h =binscatter(x,y,100);
            colormap(gca,'turbo') %jet
            colorbar('off')
            
            %----------------------            
            % add the hist for two directions  
            % change the axis range here
            %----------------------
%             if isempty(obj.xlim)    
%             else
%               h.XLimits=obj.xlim;
%             end     
%             if isempty(obj.ylim)
%             else
%                 h.YLimits=obj.ylim;
%             end
%  
%             tmp = obj.gethist_norm(h,x,y);
%             hold on
%             h2=plot(tmp.x1,tmp.y1,'-m',tmp.x2,tmp.y2,'-m');
%             axis([h.XLimits h.YLimits])                         
            xlabel(label1);
            ylabel(label2);
        end
        %for slice enformation
        %---------------------
        function plotsli(obj,option)
            if strcmp(option,'I')
                x=obj.sliz*1e3;
                y=obj.sliI;
                label1='z (mm)';
                label2='current (A)';
            elseif strcmp(option,'enx')
                x=obj.sliz*1e3;
                y=obj.slienx*1e6;
                label1='z (mm)';
                label2='slice norm. emit. (mm mrad)';
            elseif strcmp(option,'eny')
                x=obj.sliz*1e3;
                y=obj.slieny*1e6;
                label1='z (mm)';
                label2='slice norm. emit. (mm mrad)';
            elseif strcmp(option,'delta')
                x=obj.sliz*1e3;
                y=obj.slidelta;
                label1='z (mm)';
                label2='slice \DeltaE/E_0';
            elseif strcmp(option,'dE')
                x=obj.sliz*1e3;
                y=obj.slidE/1e6;
                label1='z (mm)';
                label2='slice \DeltaE (MeV)';
            elseif strcmp(option,'x0')
                x=obj.sliz*1e3;
                y=obj.slix0*1e3;
                label1='z (mm)';
                label2='slice <x> (mm)';
            elseif strcmp(option,'y0')
                x=obj.sliz*1e3;
                y=obj.sliy0*1e3;
                label1='z (mm)';
                label2='slice <y> (mm)';                
            else
                error('Unknown option:%s\n',option);                
            end
            
            h=plot(x,y,'-')
            xlabel(label1);
            ylabel(label2);
            %axis([obj.xlim obj.ylim])                                  
        end
        
        % others
        % ===================================
        function plothist(obj,Xj)
                [cnt, x] = histcounts(Xj,100);
                h = plot(x(1,1:end-1),cnt);
                xlabel(' ')
                ylabel('counts')      
                obj.setfont()
                set(h,'LineWidth',2)
        end
        
        function out=gethist_norm(obj,h,z,dgam)
            % get the hist of az(a.z, a.dgam,...)
            [x1, y1] = histcounts(dgam,100);
            y1 = y1(1,1:end-1);
            x1 = x1/max(x1)*0.2; %0.2 is the ratia of the axis
            x1 = x1*(h.XLimits(2)-h.XLimits(1))+h.XLimits(1)*1.0001;            
            
            [y2, x2] = histcounts(z,100);
            x2 = x2(1,1:end-1);
            y2 = y2/max(y2)*0.2;
            y2 = y2*(h.YLimits(2)-h.YLimits(1))+h.YLimits(1)*1.0001;
            
            out.x1 = x1;
            out.y1 = y1;            
            out.x2 = x2;
            out.y2 = y2;
            
        end
        
        function out=gethist(obj,z)
            [cnt, x] = histcounts(z,100);
            x = x(1,1:end-1,1);
            dx = x(2)-x(1);
            y = cnt; 
            out.x = x;
            out.y = y;
            out.dx = dx;
        end          
    end
end

            
      