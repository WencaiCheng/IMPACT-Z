classdef impzevo < handle
    properties
        s
        x0
        sigx
        xp0
        sigxp
        alphax
        enx
        betax
        gammax
        etax
        etaxp
        turn
        
        %s
        y0
        sigy
        yp0
        sigyp
        alphay
        eny
        betay
        gammay
        etay
        etayp
        %turn
        
        %s
        z0
        sigz
        dE0        %MeV
        sigdE      %MeV
        alphaz
        enz        %deg-MeV
        
        %s
        phi        %rad
        gam0
        w0         %kinetic energy[MeV]
        bet0
        Rmax
        
    end
    methods
        function obj=impzevo(path)            
            if nargin==0
                path='.';                
            end
            fort24file = [path '/fort.24'];  
            fort25file = [path '/fort.25'];  
            fort26file = [path '/fort.26'];  
            fort18file = [path '/fort.18'];  
                            
            fort24 = importdata(fort24file,' ');
            obj.s     = fort24(:,1);
            obj.x0    = fort24(:,2);
            obj.sigx  = fort24(:,3);
            obj.xp0   = fort24(:,4);
            obj.sigxp = fort24(:,5);
            obj.alphax= fort24(:,6);
            obj.enx   = fort24(:,7);
            obj.betax = fort24(:,8);
            obj.gammax= fort24(:,9);
            obj.etax  = fort24(:,10);
            obj.etaxp = fort24(:,11);
            obj.turn  = fort24(:,12);

            fort25 = importdata(fort25file,' ');
            %obj.s     = fort25(:,1);
            obj.y0    = fort25(:,2);
            obj.sigy  = fort25(:,3);
            obj.yp0   = fort25(:,4);
            obj.sigyp = fort25(:,5);
            obj.alphay= fort25(:,6);
            obj.eny   = fort25(:,7);
            obj.betay = fort25(:,8);
            obj.gammay= fort25(:,9);
            obj.etay  = fort25(:,10);
            obj.etayp = fort25(:,11);
            %obj.turn  = fort25(:,12);

            fort26 = importdata(fort26file,' ');
            %obj.s     = fort26(:,1);
            obj.z0    = fort26(:,2);
            obj.sigz  = fort26(:,3);
            obj.dE0   = fort26(:,4);
            obj.sigdE = fort26(:,5);
            obj.alphaz= fort26(:,6);
            obj.enz   = fort26(:,7);

            fort18 = importdata(fort18file,' ');
            obj.phi = fort18(:,2);
            obj.gam0= fort18(:,3);
            obj.w0  = fort18(:,4);
            obj.bet0= fort18(:,5);
            obj.Rmax= fort18(:,6);
            
        end           
        
        % group plot 
        % ========================
        function evogroup(obj)
            subplot(2,3,1)
            plot(obj.s,obj.betax,obj.s,obj.betay)
            legend('\beta_x','\beta_y')
            xlabel('s (m)')
            ylabel('twiss para. (m)')
            xlim([-5 max(obj.s)])
            
            subplot(2,3,2)
            plot(obj.s,obj.sigx*1e3,obj.s,obj.sigy*1e3)
            legend('\sigma_x','\sigma_y')
            xlabel('s (m)')
            ylabel('rms size (mm)')
            xlim([-5 max(obj.s)])
            
            subplot(2,3,3)
            %plot(obj.s,obj.Rmax*1e3)
            %xlabel('s (m)')
            %ylabel('R_{max} (mm)')            
            plot(obj.s,obj.x0*1e3,obj.s,obj.y0*1e3)
            xlabel('s (m)')
            ylabel('ave. position (mm)')
            legend('<x>','<y>')
            xlim([-5 max(obj.s)])
            
            subplot(2,3,4)
            plot(obj.s,obj.enx*1e6,obj.s,obj.eny*1e6)
            legend('enx','eny')
            xlabel('s (m)')
            ylabel('norm. emit. (mm mrad)')
            xlim([-5 max(obj.s)])
            
            subplot(2,3,5)
            plot(obj.s,obj.sigz*1e3)
            xlabel('s (m)')
            ylabel('\sigma_z (mm)')
            xlim([-5 max(obj.s)])
            
            subplot(2,3,6)
            plot(obj.s,obj.w0)
            xlabel('s (m)')
            ylabel('kinetic energy (MeV)')
            xlim([-5 max(obj.s)])
            
            set(gcf,'unit','normalized','position',[0,0,1,1]);
        end 
        function evogrouplog(obj)
            
            subplot(2,3,1)
            semilogy(obj.s,obj.betax,obj.s,obj.betay)
            legend('\beta_x','\beta_y')
            xlabel('s (m)')
            ylabel('twiss para. (m)')   
            xlim([-5 max(obj.s)])
            set(gca,'YMinorTick','on','tickLength',[0.02;0.02])
            
            subplot(2,3,2)
            semilogy(obj.s,obj.sigx*1e3,obj.s,obj.sigy*1e3)
            legend('\sigma_x','\sigma_y')
            xlabel('s (m)')
            ylabel('rms size (mm)')
            xlim([-5 max(obj.s)])
            set(gca,'YMinorTick','on','tickLength',[0.02;0.02])
            
            subplot(2,3,3)
            semilogy(obj.s,obj.Rmax*1e3)
            xlabel('s (m)')
            ylabel('R_{max} (mm)')            
            xlim([-5 max(obj.s)])
            set(gca,'YMinorTick','on','tickLength',[0.02;0.02])
            
            subplot(2,3,4)
            semilogy(obj.s,obj.enx*1e6,obj.s,obj.eny*1e6)
            legend('enx','eny')
            xlabel('s (m)')
            ylabel('norm. emit. (mm mrad)')
            xlim([-5 max(obj.s)])
            set(gca,'YMinorTick','on','tickLength',[0.02;0.02])
            
            subplot(2,3,5)
            semilogy(obj.s,obj.sigz*1e3)
            xlabel('s (m)')
            ylabel('\sigma_z (mm)')
            xlim([-5 max(obj.s)])
            set(gca,'YMinorTick','on','tickLength',[0.02;0.02])
            
            subplot(2,3,6)
            plot(obj.s,obj.w0)
            xlabel('s (m)')
            ylabel('kinetic energy (MeV)')
            xlim([-5 max(obj.s)])
            
            set(gcf,'unit','normalized','position',[0,0,1,1]);            
        end
         
    end
end

            
      
