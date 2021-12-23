clear all
clc

a = impzphase('fort.1005');
a1=impzslice('fort.11005');

%% 3*3 phase space plot
a.plot33()

%% 2D density plot
figure
x = a.z*1e6;
y = a.dgam;
y = y+a.z*3000*100;

a.plot2d(x,y)
xlabel('z (um)')
ylabel('\Delta\gamma')

% or use
figure
a.plot2d(561)

%% density hist plot
figure
a.plothist(a.z*1e6)

%% slice information
figure
a1.plotij('dE')

figure
a1.plotij('enx')
