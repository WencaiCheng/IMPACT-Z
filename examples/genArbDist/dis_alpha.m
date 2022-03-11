clear all
clc

%%
Np=1e5;
gam0 = 100/0.511;

alphax= 1;
betax = 10;
ex   = 0.2e-6/gam0;

alphay= -1;
betay = 10;
ey   = 0.2e-6/gam0;
%%
sig1  = sqrt(ex*betax/(1+alphax^2));
sig2  = sqrt(ex/betax);
sig12 = alphax/(1+alphax^2);

sig3  = sqrt(ey*betay/(1+alphay^2));
sig4  = sqrt(ey/betay);
sig34 = alphay/(1+alphay^2);

U=rand(Np,6);
zeta=sqrt(2)*erfinv(2*U-1);

zeta1 = zeta(:,1);
zeta2 = zeta(:,2);
zeta3 = zeta(:,3);
zeta4 = zeta(:,4);
zeta5 = zeta(:,5);
zeta6 = zeta(:,6);

fac = sqrt(1-sig12^2);
x = sig1*zeta1/fac;
xp= sig2*(-sig12/fac*zeta1 + zeta2);

y = sig3*zeta3/fac;
yp= sig4*(-sig34/fac*zeta3 + zeta4);

%%
figure
plot(x,xp,'.')

figure
plot(y,yp,'.')

