/
 * Created by aris on 11/16/17.
 Multivariate Normal Distribution helper functions
 https://en.wikipedia.org/wiki/Multivariate_normal_distribution#Drawing_values_from_the_distribution
\

/
 Box Muller Transform
 args: no arg
 return: 2 std normal variates
 check for normality
 qchart.histbar select y:count i by 0.1 xbar x from ([]x:raze .qstats.stdnormalBoxMuller each til 10000)
\
.qstats.stdnormalBoxMuller:{{$[(s<1)&0<s:(x*x)+y*y;(x;y)*sqrt -2*log[s]%s;.z.s . -1+2?2f]}.-1+2?2f}

/
 Generate n normal variates from N(m,s)
 args: n: number of normal variates
       m: mean of normal distribution to sample
       s: standard deviation of normal distribution to sample
 return: a float list of normal variates
\
.qstats.genNormalVariates:{[n;m;s] m + s * raze .qstats.stdnormalBoxMuller each til ceiling .5*n }

/
 Cholesky–Banachiewicz algorithm
 https://en.wikipedia.org/wiki/Cholesky_decomposition
 args: a Hermitian, positive-definite matrix A
 return: the lower triangular matrix L of the Cholesky decomposition
 validate: A~.qstats.cholesky[A] mmu flip .qstats.cholesky[A]
\
.qstats.cholesky:{[A]
 L:0f*A;
 i:j:0;
 do[floor (N*1+N:count A)%2;
  L[i;j]: $[b:i=j; sqrt A[i;j] - {x$x} j#L[j] ;  reciprocal[L[j;j]] * A[i;j] - (i#L i)$i#L j];
  i:i+b;
  j:(j+nb)*nb:not b;
 ];
 L}

/ version using over - memory intensive and therefore slower
.qstats.cholesky1:{[A]
 iterator:{[A;Li]
  L:first Li;
  i: last[Li] 0; j: last[Li] 1;
  L[i;j]:$[b:i=j; sqrt A[i;j] - {x$x} j#L[j] ;  reciprocal[L[j;j]] * A[i;j] - (i#L i)$i#L j];
  (L;(i+b;(j+nb)*nb:not b))
 }[A];
 N:floor (N*1+N:count A)%2;
 first N iterator/(0f*A;0 0)
 }
