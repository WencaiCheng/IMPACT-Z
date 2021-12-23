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
    end
    methods
        function obj=impzphase(filename)
            tmp = importdata(filename,' ',1);
            obj.headstr = tmp.textdata;
            obj.data    = tmp.data;
            obj.x       = obj.data(:,1);
            obj.xp      = obj.data(:,2);
            obj.y       = obj.data(:,3);
            obj.yp      = obj.data(:,4);
            obj.z       = obj.data(:,5);
            obj.dgam    = obj.data(:,6);
            obj.delta   = obj.data(:,7);
        end           
        
        function plot2d(obj,option,col2)
            if nargin<3
        
                if option==561
                    % use x,y, convenient for change units
                    x=obj.z*1e3;
                    y=obj.dgam;  
                    label1 = 'z (mm)';
                    label2 = '\Delta\gamma'; 
                elseif option==562
                    % use x,y, convenient for change units
                    x=obj.z*1e3;
                    y=obj.delta;  
                    label1 = 'z (mm)';
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
            else
                x=option;  %option is col1 now
                y=col2;
                % label set by outside
                label1='x';  
                label2='y';
            end    
                
            %--------------------
            h =binscatter(x,y,100);
            colormap(gca,'turbo') %jet
            colorbar()
            
            % add the hist for two directions   
            tmp = obj.gethist(h,x,y);
            hold on
            plot(tmp.x1,tmp.y1,'-m',tmp.x2,tmp.y2,'-m')
            xlabel(label1);
            ylabel(label2);
            axis([h.XLimits h.YLimits])
            
            obj.setfont();
                
        end
        
        function plothist(obj,z)
                [cnt, x] = histcounts(z,100);
                h = plot(x(1,1:end-1),cnt)
                xlabel(' ')
                ylabel('counts')      
                obj.setfont()
                set(h,'LineWidth',2)
        end
        
        function out=gethist(obj,h,z,dgam)
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
        
        function plot33(obj)
            figure
            subplot(3,3,1)
            obj.plot2d(12)
            subplot(3,3,2)
            obj.plot2d(34)
            subplot(3,3,3)
            obj.plot2d(13)
            subplot(3,3,4)
            obj.plot2d(51)
            subplot(3,3,5)
            obj.plot2d(52)
            subplot(3,3,6)
            obj.plot2d(561)           
            subplot(3,3,7)
            obj.plot2d(53)
            subplot(3,3,8)
            obj.plot2d(54)
            subplot(3,3,9)
            obj.plot2d(562)
            
        end
            
        function setfont(obj)
            FS=25;
            LW=2;
            
            set(gcf,'color','w');
            set(gca,'FontSize',FS,'LineWidth',LW);
        end            
        
    end
end

            
      