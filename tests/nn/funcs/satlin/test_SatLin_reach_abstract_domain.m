
I = ExamplePoly.randVrep;   
V = [0 0; 1 0; 0 1];
I.outerApprox;
lb = I.Internal.lb;
ub = I.Internal.ub;
I = Star(V', I.A, I.b, lb, ub); % input star
X = I.sample(100);

figure;
I.plot;
hold on;
plot(X(1, :), X(2, :), 'ob'); % sampled inputs

S = SatLin.reach_abstract_domain(I); % over-approximate reach set
S1 = SatLin.reach(I); % exach reach set

Y = SatLin.evaluate(X);

figure;
S.plot;
hold on;
Star.plots(S1);
hold on;
plot(Y(1, :), Y(2, :), '*'); % sampled outputs
