clear all
clc

a = impzphase('fort.1005');
a1=impzslice('fort.11005');

%%
figure
x = a.z*1e6;
y = a.dgam;
y = y+a.z*3000*100;

a.plot2d(x,y)
xlabel('z (um)')
ylabel('dgam')

%%
figure
a.plothist(a.z*1e6)

%% 
figure
a.plot2d(562)


%%
figure
a1.plotij('dE')

%%
figure
a1.plotij('enx')
