clear all
clc
% close all

pha2 = impzphase('1002');
pha3 = impzphase('1003');
pha5 = impzphase('1005');
pha6 = impzphase('1006');

%% compression factor
c1 = std(pha2.z)/std(pha3.z);
c2 = std(pha3.z)/std(pha5.z);

sigzf = std(pha5.z);
sigdelta = std(pha6.delta);
c = c1*c2;

%%
figure(1)
subplot(2,3,1)
plot(pha2.z,pha2.dgam,'.')
hold on
plot(pha3.z,pha3.dgam,'.')

subplot(2,3,2)
plot(pha5.z,pha5.delta,'.')
hold on
plot(pha6.z,pha6.delta,'.')
% 
% current plot
Q=75e-12;
Np=length(pha2.z);
clight=2.998e8;
current = @(pha) pha.histz.y*Q/Np*clight/pha.histz.dx;

subplot(2,3,4)
plot(pha2.histz.x,current(pha2))
% hold on

subplot(2,3,5)
plot(pha3.histz.x,current(pha3))
% hold on

subplot(2,3,6)
plot(pha6.histz.x,current(pha6))

%%
figure
plot(pha6.z,pha6.delta,'.')

%%
% figure()
% subplot(1,2,1)
% plot(pha2.z,pha2.dgam,'.')
% hold on
% plot(pha3.z,pha3.dgam,'.')
% hold on
% plot(pha5.z,pha5.dgam,'.')
% % 
% % %% current plot
% Q=75e-12;
% Np=length(pha2.z);
% clight=2.998e8;
% current = @(pha) pha.histz.y*Q/Np*clight/pha.histz.dx;
% 
% subplot(1,2,2)
% plot(pha2.histz.x,current(pha2))




% % hold on
% % 
% % plot(pha3.histz.x,current(pha3))
% hold on
% 
% figure
% plot(pha5.histz.x,current(pha5))

% xlim([-1e-3,1e-3])





