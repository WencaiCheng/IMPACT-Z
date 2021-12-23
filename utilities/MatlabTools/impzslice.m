classdef impzslice < handle
    properties
        z
        np
        current
        enx
        eny
        delta
        dE
        x0
        y0
       
    end
    methods
        function obj=impzslice(filename)
            tmp = importdata(filename);
            obj.z = tmp(:,1);
            obj.current = tmp(:,3);
            obj.enx     = tmp(:,4);
            obj.eny     = tmp(:,5);
            obj.delta   = tmp(:,6);
            obj.dE      = tmp(:,7);
            obj.x0      = tmp(:,8);
            obj.y0      = tmp(:,9);
        end
        
        function plotcurrent(obj)
            plot(obj.z,obj.current)
            xlabel("z (m)");
            ylabel("current (A)")
        end
        
        function plotij(obj,option)
            if strcmp(option,'current')
                x=obj.z*1e3;
                y=obj.current;
                label1='z (mm)';
                label2='current (A)';
            elseif strcmp(option,'enx')
                x=obj.z*1e3;
                y=obj.enx*1e6;
                label1='z (mm)';
                label2='enx (mm mrad)';
            elseif strcmp(option,'eny')
                x=obj.z*1e3;
                y=obj.eny*1e6;
                label1='z (mm)';
                label2='eny (mm mrad)';
            elseif strcmp(option,'delta')
                x=obj.z*1e3;
                y=obj.delta;
                label1='z (mm)';
                label2='\DeltaE/E';
            elseif strcmp(option,'dE')
                x=obj.z*1e3;
                y=obj.dE/1e6;
                label1='z (mm)';
                label2='\DeltaE (MeV)';
            elseif strcmp(option,'x0')
                x=obj.z*1e3;
                y=obj.x0*1e3;
                label1='z (mm)';
                label2='<x> (mm)';
            elseif strcmp(option,'y0')
                x=obj.z*1e3;
                y=obj.y0*1e3;
                label1='z (mm)';
                label2='<y> (mm)';                
            else
                error('Unknown option:%s\n',option);                
            end
            
            h=plot(x,y,'-b')
            xlabel(label1);
            ylabel(label2);
            
            obj.setfont(h);
            
        end
        
        function setfont(obj,h)
            FS=25;
            LW=2;
            
            set(gcf,'color','w');
            set(gca,'FontSize',FS,'LineWidth',LW);
            
            set(h,'LineWidth',LW); 
        end    
        
    end
end

            
      