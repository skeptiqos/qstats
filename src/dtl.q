/ * Created by aris on 12/23/17.
/ Decision tree learning and random forests
/ tree construction based on http://archive.vector.org.uk/art10500340

/ Classify Y observation (predicted). use for classification tree
/ @param
/  breakpoints: sorted list to bucket (classify) predicted variable sample
/  y          : vector of sampled predicted variable
/ @return
/  vector of classified predicted variable
/ @example:
/  .dtl.classify[-50 0 50f;y]
/  1 1 1 0 0 0
.dtl.classify:{[breakpoints;y] asc[breakpoints] binr y}

/ Entropy Gain for given classification
/ @param
/  y       : vector of sampled predicted variable
/  classes : domain we wish to classify y, the distinct classes
/ @return
/  entropy as a float atom
/ @example
/  .dtl.entropy[.dtl.classify[-50 0 50f;y];0 1]
.dtl.entropy:{[y;classes]
 p:{sum[x=y]%count x}[y]each classes;
 /p:((count each group y)%count y)classes;
 neg p wsum 2 xlog p
 }

/ Information gain for a given classification (split)
/ https://en.wikipedia.org/wiki/Information_gain_in_decision_trees
/ @param
/  yp     : the parent node classification set of attributes
/  ysplit : the child nodes classifications set of attributes after the split
/  classes: the set of classes
/ @return
/  information gain as a float atom
.dtl.infogain:{[yp;ysplit;classes].dtl.entropy[yp;classes] - (wsum). flip ({count[y]%count x}[yp];.dtl.entropy[;classes])@\:/:ysplit}

.dtl.applyRule:{[cbm;bmi;xi;rule;j]
 (`bitmap`appliedrule!( @[zb; bmi;:;] not b; not);
  `bitmap`appliedrule!( @[zb:cbm#0b; bmi;:;] b:eval (rule;xi;j); (::)))}

.dtl.runRule:{[rule;i;j;x] rule[x i;j]}

.dtl.chooseSplitXi:{[yy;y;cbm;bmi;rule;classes;xi]
  j:asc distinct xi;
  info:{[yy;y;cbm;bmi;xi;rule;classes;j]
   split:.dtl.applyRule[cbm;bmi;xi;rule;j];
   (.dtl.infogain[y;{x where y}[yy] each split[`bitmap];classes];split)
   }[yy;y;cbm;bmi;xi;rule;classes] each j;
   (j;info)@\:first idesc flip[info]0
 }

/ Choose optimal split for a node
/ find the split which maximizes information gain by iterating over all splits
/ @param  xy:  dict of
/              predictor (`x) set
/              predicted (`y) vector
/              distinct vector of k classification classes (`classes)
/              number of predictor vectors to sample (`m)
/         treeinput: dict of
/           logical rule to apply (`rule)
/           list of rules (`rulepath)
/           bitmap of indices of x and y being processed in current iteration
/ @return xi:       the index of the predictor to split on
/         j:        the position of the rule split ( x[i]>j ) ( x[i]<=j )
/         infogains: the information gain for each of the splitted j's
/         infogain: how much information is gained by splitting at x[i]>j
/         bitmap:   the indices of splitted x and y
/         rulepath: the full path of rules applied to node
/ @example .dtl.chooseSplit[x;.dtl.classify[-50 0 50f;y];>;0 1]
.dtl.chooseSplit:{[xy;treeinput]
 bm: treeinput`bitmap;
 x: xy[`x][;bmi: where bm];
 y: xy[`y][bmi];
 classes: xy`classes;
 m: xy`m;
 rule: treeinput`rule;rulepath: treeinput`rulepath;
 cx:count x;
 info: .dtl.chooseSplitXi[xy`y;y;count bm;bmi;rule;classes]peach x@sampled:asc neg[m]?cx;
 /info: .Q.fc[ .dtl.chooseSplitXi[xy`y;y;count bm;bmi;rule;classes]each] x@sampled:asc neg[m]?cx;
 summary: (`infogains`xi`j`infogain!enlist[sampled!is],i,(-1_r)),/:last r:raze info i:first idesc is:info[;1;0];
 cnt: count summary;
 update rule:rule,
        rulepath:{[rp;ar;r;i;j] rp,enlist (ar;(`.dtl.runRule;r;i;j))}[rulepath]'[appliedrule;rule;xi;j]
        from summary
 }

.dtl.growTree:{[xy;r]
 {[xy;r]
  if[1>=count distinct xy[`y]where r`bitmap;:r];
  enlist[r],$[98h<>type rr:.dtl.growTree[xy;r];raze @[rr;where 99h=type each rr;enlist];rr]
 }[xy]each  r:.dtl.chooseSplit[xy;r]}



/ Learn a tree: for each of the records in the initial split, we iterate until we reach pure nodes (leaves)
/ when we reach a leaf we return flattened result and then recurse over the next split record until there are none left
/ the flattened tree should contain all the paths and a tree like structure with all indices i and parents p
/ @param
/  dictionary with  keys
/  `xi       : index of x predictor. initialise i of predictor xi as null, we will iterate over all of them
/  `j        : initialise j split as null, we will iterate over all of them
/  `infogain : inleitialise info gain to null, this will be populated with the information gain at each split
/  `x`y`rule`classes: these are input params with `x`y denoting initial sampled z set
/ @return  a treetab structure
.dtl.learnTree:{[params]
 params[`m]: $[`m in key params;params`m;count params`x];
 r0:`infogains`xi`j`infogain`bitmap`x`y`appliedrule`rule`rulepath`classes`m#
     params,`infogains`xi`j`infogain`bitmap`appliedrule`rulepath!(()!();0N;0N;0n;count[params`y]#1b;::;());
 tree: enlist[r0],
       $[98<>type r:.dtl.growTree[; r0:dc _r0] (dc:`x`y`classes`m)#r0;
         raze @[r;where 99h=type each r;enlist];
         r];
 tree: update p:{x?-1_'x} rulepath  from tree;
 `i`p`path xcols update path:{(x scan)each til count x}p,i:i from tree}

/ Return a subtree containing only the leaves
.dtl.leaves:{[tree] select from tree where i in til[count p]except p}

/ predict Y (classify) given a tree and an input Xi
/ @param
/  tree : a previously grown tree
/  x    : a tuple of the features at a data point i, ie X[i]
/ @return
/     apply the rules of tree to X[i] using the previously constructed `ruelpath field
/     and return the tree record containing the classification
.dtl.predictOnTree:{[tree;x]
 ({[x;tree]
  if[1=count tree;:tree];
  @[tree;`rulepath;1_'] where {value y[0],value[y 1]x}[x]each tree[`rulepath][;0]
  }[x]over)[.dtl.leaves tree]
 };


/ SampleTree: used for bootstrapping, samples a subset of the dataset to grow a tree from
/ @param
/  s: dataset `x`y!(predictors;predicted)
/  n: sample size
/ @return a dictionary of
/          `x`y : subsets of predictors and corresponding predicted values
/          `oobi: indices of data sample n which were not included (out of bag sample)
/ @example
/ .dtl.sampleTree[`x`y!(x;y);count y]
.dtl.sampleTree:{[s;n]
 z:`x`y!(s[`x][;i];s[`y]i:n?n);
 z,`ibi`oobi!( i ; (til n) except distinct i )}


/ Draw a bootstrap sample of size N from the training data and calculate the out of bag error:
/ For all features which were not sampled (out of bag) for that tree, predict their values and measure the prediction error
/ @param
/  params: dictionary with tree input params. see: .dtl.learnTree
/  n: sample size for bootstrap
/  m: number of features to randomly sample on each node split
/  B: the index of bootstrap sample
/ @return
.dtl.bootstrapTree:{[params;m;n;B]
 z: .dtl.sampleTree[`x`y#params;n];
 tree_b:   .dtl.learnTree @[params;`x`y;:;z`x`y],enlist[`m]!enlist m;
 tree_oob: raze .dtl.predictOnTree[tree_b]each flip params[`x;;z`oobi];
 tree_oob: update pred_error:abs obs_y-{first x where y}[z`y]each bitmap from
            update obs_y:params[`y]z`oobi from tree_oob;
 `tree`oob`ibi!(`B xcols update B from tree_b;`B xcols update B from tree_oob;enlist `B`ibi!(B;z`ibi))
 }

/ Random Forest
/ @param
/  params: dictionary with keys
/     x       : predictor
/     y       : predicted
/     rule    : the logical rule to apply
/     classes : the k classification classes for y
/     m       : the number of random features to sample at each split point (for classification m is usually set to sqrt p, where p=count features)
/     n       : sample size for bootstrapping
/     B       : number of bootstrap trees
.dtl.randomForest:{[params]
 ensemble: .dtl.bootstrapTree[params;params`m;params`n] each til params`B;
 raze each flip ensemble}

/ Predict classification of x (data), given an ensemble
/ @param
/     y        : predicted variable vector
/     ensemble : a random forest: a table of treetables
/     data     : datapoint to predict classification on: vector of m features
/ @return
/ classification of x based on majority rule
.dtl.predictOnRF:{[y;ensemble;data]
 rf:{[data;tree;ibi;b]
     prediction: .dtl.predictOnTree[select from tree where B=b] data;
     update bi: (exec ibi from ibi where B=b) from prediction
     }[data;tree;ensemble`ibi] each exec distinct B from tree:ensemble`tree;
 prediction: {first where x=max x}count each group exec {first x[y] where z}[y]'[bi; bitmap] from raze rf;
 `prediction`mean_error!( prediction; exec avg pred_error from ensemble`oob )
 }

\

iris:("FFFFS";enlist csv)0:`:/var/tmp/iris.csv;
dataset:()!();
dataset[`x]:value flip delete species from iris;
dataset[`y]:{distinct[x]?x} iris[`species];
params: dataset,`rule`classes!(>;asc distinct dataset`y);

\ts tree:.dtl.learnTree params

abalone:("SFFFFFFFI";enlist csv)0:`:/var/tmp/abalone.data;
abalone:delete sex from update male:?[sex=`M;1;0],female:?[sex=`F;1;0],ii:?[sex=`I;1;0] from abalone;
data:abalone;
dataset:()!();
dataset[`x]:value flip delete rings from data;
dataset[`y]: data[`rings];
params: dataset,`rule`classes!(>;asc distinct dataset`y);

/ q dtl.q -s 4
\ts tree:.dtl.learnTree params
23194 2997024

// random forest


iris:("FFFFS";enlist csv)0:`:/var/tmp/iris.csv;
dataset:()!();
dataset[`x]:value flip delete species from iris;
dataset[`y]:{distinct[x]?x} iris[`species];
params: dataset,`rule`classes!(>;asc distinct dataset`y);

\ts ensemble:.dtl.randomForest params,`m`n`B!(4;0N!count dataset`y;100)

.dtl.predictOnRF[0N!params`y;ensemble;0N! value `species _ iris 0]  / correct
.dtl.predictOnRF[0N!params`y;ensemble;0N! value `species _ iris 1]  / correct
.dtl.predictOnRF[0N!params`y;ensemble;0N! value `species _ iris 77] / correct
.dtl.predictOnRF[0N!params`y;ensemble;0N! value `species _ iris 149] / correct

mean_error| 0.06950226

/ however, reducing m causes inacuracies...

.dtl.predictOnRF[0N!params`y;ensemble;0N! value `species _ iris 0]  / incorrect
.dtl.predictOnRF[0N!params`y;ensemble;0N! value `species _ iris 1]  / incorrect
.dtl.predictOnRF[0N!params`y;ensemble;0N! value `species _ iris 77] / incorrect
.dtl.predictOnRF[0N!params`y;ensemble;0N! value `species _ iris 149] / correct

mean_error| 0.5421272




\ts ensemble:.dtl.randomForest params,`m`n`B!(5;count params`y;10)





