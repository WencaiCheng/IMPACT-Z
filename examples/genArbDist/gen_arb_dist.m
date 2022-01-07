clear all
clc

%% setting paras
N1   = 1e3;         % bin number
Np   = 1e5;         % particle number
sigz = 0.2e-3;      % m
Q    = 75e-12;      % C

%% density profile
% get the fitting function of current profile
x0 = [0, 0.2, 0.5, 0.8, 1]';
y0 = [0, 0.6, 0.7, 0.6, 0]';

tmp = fit(x0,y0,'poly4');

% figure()
% plot(x0,y0,'-o')
% figure()
% plot(tmp,x0,y0,'-o')

%% get the fz
% for gauss and some dists, re-size z to range of (0,1)
% after getting the fx data

%%%% shape from fitting
% z0 = linspace(0,1,N1);
% fz =  tmp(z0);
% fz = fz';

%%%% shape for x^2
z0 = linspace(-1,1,N1);
fz = -z0.^2;
fz =  fz+abs(min(fz));
z0 = (z0+1)/2;  %move to (0,1)

%%%% shape for CSR compensation
% z0 = linspace(0,1,N1);
% fz = z0.^(1/3);

%%%% gauss dis
% z0 = linspace(-5,5,N1);
% fz = exp(-z0.^2/2);
% z0 = (z0+5)/2;


%%% normalize the fz
% over 2 to resize (0,1) to (-1,1)
fz = fz/trapz(z0,fz)/2;  

% figure
% plot(z0,fz)

%% get the rms z value
z1 = 2*z0-1;   %move to (-1,1) xrange
sigz1 = sqrt( trapz(z1,z1.^2.*fz) );

figure
plot(z1,fz)

%% CDF function
Fz = cumtrapz(z0,fz);
Fz = Fz/Fz(end);

figure
plot(z0,Fz)

%% save to data
Mfile = [z0' fz' Fz'];
% save('zprofile.in','Mfile','-ascii')

fileid = fopen('zprofile.in','w');
fprintf(fileid,'  %d \n',N1);
fprintf(fileid,'%15.7e %15.7e %15.7e \n',Mfile');
fclose(fileid);


%% halton sequence setting
p = haltonset(1,'Skip',1000,'Leap',100);
p = scramble(p,'RR2');
X0 = net(p,Np);

% Inverse sampling
for j=1:Np
    U=X0(j);
    samples(j)=2*interp(z0,Fz,U,N1)-1;
end

z = sigz/sigz1*samples;
% z = samples;
%% figure
figure()
h = histogram(z,256);
xlabel('z (m)')
ylabel('particle number')
% setplot(h,'chap6_cosDis.png','boxoff')

%%
I = h.Values *const.c_mks *Q./(h.BinWidth*Np);
figure()
h = plot(h.BinEdges(2:end-1),I(2:end));
% axis([-3,3,15,25])
% set(gca,'YMinorTick','on')
xlabel('z (m)')
ylabel('current (A)')
% setplot(h,'chap6_cosDis.png','boxoff')

%% functions
function sample=interp(x,Fx,U,Nbin)
    lo=1;
    hi=Nbin;
    while (hi-lo)>1
        mid = round((lo+hi)/2);
        if U<Fx(mid)
            hi=mid;
        else
            lo=mid;
        end
    end
    sample = LagrangeInterp(x,Fx,U,lo);
end
% 
function sample = LagrangeInterp(x,Fx,U,lo)
    sum=0; 
    for i=0:1
        denom=1;
        numer=1;
        for j=0:1
            if i~=j
                denom=denom*(Fx(lo+i)-Fx(lo+j));
                numer=numer*(U-Fx(lo+j));
                if numer==0
                    sample=x(lo+j);
                    return;
                end
            end
        end
        if denom==0
            sample=0;
            return;
        end
        sum=sum+x(lo+i)*numer/denom;
    end
    sample=sum;
end

















