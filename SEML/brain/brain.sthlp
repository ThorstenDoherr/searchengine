{smcl}
{* 19may2021}{...}
{hline}
help for {hi:brain}
{hline}

{title:Neural Network}

{p 8}{cmd:brain {ul:de}fine} [{it:if}] [{it:in}], {ul:in}put({it:varlist}) {ul:o}utput({it:varlist}) [{ul:h}idden({it:numlist})] [{ul:s}pread({it:default = 0.25})] [{ul:r}aw | {ul:n}onorm]

{p 8}{cmd:brain {ul:no}rm} {it:varlist} [{it:if}] [{it:in}], [{ul:r}aw]

{p 8}{cmd:brain {ul:re}set}, [{ul:s}pread({it:default = 0.25})]

{p 8}{cmd:brain {ul:sa}ve} {it:filename}

{p 8}{cmd:brain {ul:lo}ad} {it:filename}

{p 8}{cmd:brain {ul:si}gnal}, [{ul:raw}]

{p 8}{cmd:brain {ul:fe}ed} {it:input_signals}, [{ul:raw}]

{p 8}{cmd:brain {ul:tr}ain} [{it:weight}] [{it:if}] [{it:in}], {ul:it}er({it:default = 0})  [{ul:e}ta({it:default = 0.25})] [{ul:ba}tch({it:default = 1})] [{ul:r}eport({it:default = 10})] [{ul:be}st] [{ul:n}oshuffle] [{ul:sp}]

{p 8}{cmd:brain {ul:er}ror} [{it:weight}] [{it:if}] [{it:in}], [{ul:sp}]

{p 8}{cmd:brain {ul:th}ink} {it:output_varlist} [{it:if}] [{it:in}], [{ul:sp}]

{p 8}{cmd:brain {ul:ma}rgin} [{it:input_varlist}] [{it:weight}] [{it:if}] [{it:in}], [{ul:sp}]

{p 8}{cmd:brain {ul:fi}t} {it:original_binary_var} [{it:predicted_var}] [{it:if}] [{it:in}], [{ul:sp}] [{ul:th}({it:default = 0.5})]

{title:Description}

{p}{cmd:brain} implements a backpropagation network based on the following matrices:{p_end}

{p}
{hi:input}{space 2}- defining input variable names, containing the input signal and normalization parameters{break}
{hi:output} - defining output variable names, containing the output signal and normalization parameters{break}
{hi:neuron} - containing neuronal signals{break}
{hi:layer}{space 2}- defining the structure of the network{break}
{hi:brain}{space 2}- containing synapse weights and neuronal bias{break}
{p_end}

{p}{hi:Be aware of potential name conflicts! Do not manually change those matrices!}{p_end}

{p}Use {cmd:matrix list} {it:matrix_name} to study the content of the network matrices.{p_end}

{title:Commands and Options}

{p 0 4}{cmd:brain}{break}
displays the used plugin, version date, the number of processors used for multiprocessing and the structure of the brain matrices. It also verifies the integrity of the structure.{break}
Stored results:{break}
r({hi:plugin}) used plugin{break}
r({hi:version}) version date{break}
r({hi:mp}) number of processors used for multiprocessing

{p 0 4}{cmd:brain {ul:de}fine}, {ul:in}put({it:varlist}) {ul:o}utput({it:varlist}) [{ul:h}idden({it:numlist})] [{ul:s}pread({it:default = 0.25})]  [{ul:r}aw | {ul:n}onorm]{break}
defines the structure of the neural network. Parameters to normalize the {hi:input} and {hi:output} variables between [0,1] are determined based on the 
active data. The normalization will be skipped if options {hi:raw} or {hi:nonorm} are specified. {hi:raw} still tests that all {hi:input} and {hi:ouput} 
variables are in the range of [0,1], while [hi:nonorm] just assumes already normalized data without verification. This is usefull, when only selected variables require 
normalization (see command {hi:norm}). The {hi:hidden} layers can be omitted, leading to a simple perceptron. If specified, every number defines 
a hidden layer of the corresponding size starting at the input layer. The starting values of the synapses are randomly distributed between
[-{hi:spread}, +{hi:spread}]. 

{p 0 4}{cmd:brain {ul:no}rm} {it:varlist}, [{ul:r}aw]{break}
subsequently normalizes specified output and/or input variables separately after an initial definition with {cmd:define}. This is useful to normalize only specific variables, while other
variables, e.g. interdependent shares summing up to 1, stay {hi:raw} and vice versa. The varlist {hi:*} can be specified to normalize the whole network. Of course, normalization can be 
performed externally without using the brain normalization, but keep in mind, that it has to be consistent for predictions beyond the training data. The {hi:input} and {hi:output} matrices
contain the internal normalization parameters. 

{p 0 4}{cmd:brain {ul:re}set}, [{ul:s}pread({it:default = 0.25})]{break}
the weights of an existing network ({hi:brain} matrix) are re-initialized according to the {hi:spread} parameter nullifying all training efforts.

{p 0 4}{cmd:brain {ul:sa}ve} {it:filename}{break}
save the neural network matrizes into a file. Default postfix is ".brn".

{p 0 4}{cmd:brain {ul:lo}ad} {it:filename}{break}
loads the neural network matrizes from a file. Default postfix is ".brn".

{p 0 4}{cmd:brain {ul:si}gnal}, [{ul:raw}]{break}
sequentially activates each input signal and reports the difference to the flatline. The signals of the flatline can be found at the bottom of the listing. Specifying {hi:raw} reports signals
in normalized form [0,1].{break}
Stored results:{break}
r({hi:signal}) matrix of input variable on output signals

{p 0 4}{cmd:brain {ul:fe}ed} {it:input_signals}, [{ul:raw}]{break}
displays the output according to the specified input signals. The option {hi:raw} declares all values as normalized input signals [0,1], otherwise
they will be interpreted according to the respective variable context. The network status can be accessed using {cmd:matrix list} on the following matrices: {hi:input}, {hi:neuron}, {hi:output}{break}
Stored results:{break}
r({hi:output}) matrix of the output signals (de-normalized and raw)

{p 0 4}{cmd:brain {ul:tr}ain} [{it:weight}], {ul:it}er({it:default = 0}) [{ul:e}ta({it:default = 0.25})] [{ul:b}atch({it:default = 1})] [{ul:r}eport({it:default = 10})] [{ul:be}st] [{ul:n}oshuffle] [{ul:sp}]{break}
initiates the backpropagation training for {hi:iter} iterations using a training factor {cmd:eta}. With the option {cmd:batch} the batch size can
be specified. If it is larger than 1, stochastic gradient descent (SGD) is applied. All gradients, determined by the backpropagation algorithm,
are accumulated to a batch gradient, which is applied to the weights. Batch training may converge faster for deep networks but the real benefit of
batch training is parallelization (see {hi:Performance and multiprocessing} below). In general, the data is reshuffled before an iteration. If
{hi:noshuffle} is specified, shuffling will be omitted. This is useful to hone the network in subsequent trainings, as the gradient decent is more
stable along the trodden path and the risk of local minima is mitigated by the initial training based on shuffling. A good strategy is to start
with shuffling (default) and improve the network by subsequent trainings with lower {hi:eta}s and {hi:noshuffle}. The parameter {hi:report}
defines the interval for the reporting of the average absolute error and the delta to the previously reported error. Especially for large
{cmd:eta}s, the error can fluctuate significantly. The parameter {hi:best} guarantees that the best network according to the {cmd:report}ed error
is used as the final result instead of the last one. This has the benefit of preserving the best network in subsequent training sessions but
requires enough memory to save a copy of the brain matrix.{break}
The training supports weights to adjust for skewed output distributions, i.e. a binary variable with extreme dominance of ones respectively
zeroes.{break}
The function will use multiprocessing unless single processing is enforced with option {cmd:sp}.{break}
Stored results:{break}
r({hi:N}) number used observations{break}
r({hi:iter}) iteration used for the final brain matrix (see {hi:best}){break}
r({hi:err}) final error

{p 0 4}{cmd:brain {ul:er}ror} [{it:weight}], [{ul:sp}]{break}
reports the average absolute error, which is the sum of all absolute errors divided by the number of obs and the number of output variables. The function supports weights.{break}
The function will use multiprocessing unless single processing is enforced with option {cmd:sp}.{break}
Stored results:{break}
r({hi:N}) number used observations{break}
r({hi:err}) average absolute error{break}

{p 0 4}{cmd:brain {ul:th}ink} {it:output_varlist}, [{ul:sp}]{break}
creates or overwrites the specified output variables with the prediction of the network. The number of output variables has to match the number
of output neurons. If an input variable exceeds the limits defined for the network, its signal will get truncated accordingly to stay in the range [0,1].{break}
The function will use multiprocessing unless single processing is enforced with option {cmd:sp}.{break}

{p 0 4}{cmd:brain {ul:ma}rgin} [{it:input_varlist}] [{it:weight}], [{ul:sp}]{break}
reports the marginal effect of the selected input variables (default = all) on the output variables by calculating the difference between the estimated output and the
output with a constant zero signal for the respective input variable.{break}
The function will use multiprocessing unless single processing is enforced with option {cmd:sp}.{break}
Stored results:{break}
r({hi:margin}) matrix of input variables on marginal output signals

{p 0 4}{cmd:brain {ul:fi}t} {it:original_binary_var} [{it:predicted_var}], [{ul:sp}] [{ul:th}({it:default = 0.5})]{break}
reports precision and recall rates for a binary variable based on the prediction of the neural network or a specified predicted variable. The predictied variable can
be omitted for univariate output. This convenient function can also be used ouside the context of brain predictions, i.e. comparing results of probit regressions. Option
{cmd:th} defines the threshold for binary one.{break}
The function will use multiprocessing unless single processing is enforced with option {cmd:sp}.{break}
Stored results:{break}
r({hi:N}) number of observations{break}
r({hi:TP}) true positives{break}
r({hi:FP}) false positives{break}
r({hi:TN}) true negatives{break}
r({hi:TP}) false negatives{break}
r({hi:Trecall}) recall for true:  TP/(TP+FN){break}
r({hi:Frecall}) recall for false: TN/(TN+FP){break}
r({hi:Tprecision}) precision for true:  TP/(TP+FP){break}
r({hi:Fprecision}) precision for false: TN/(TN+FN){break}
r({hi:accuracy}) accurary: (TP+TN)/(TP+TN+FP+FN){break}
r({hi:threshold}) threshold for binary one

{title:Normalization}

{p}An Artificial Neural Network (ANN) simulates very roughly the signal processing in the brain. Therefore, it is essential that all 
signals passing through the brain matrix have a limited strength to prevent overloading. In this implementation, the signals are always 
in the range between 0 and 1. During the definition of the brain with the command {cmd:define}, the {hi:input} and {hi:output} matrices 
contain  normalization parameters based on the active training data to provide appropriate normalization not only for training but also 
for later predictions. Sometimes, data is already within the valid range, which can be declared with the parameter {cmd:raw} during 
definition. If only specific variables require normalization, it can be skipped with the parameter {cmd:nonorm}. The command {cmd:norm} 
allows for subsequent normalizations of groups of variables to enable a mix of normalized and raw variables. Skipping normalization is 
only required, if variables are interdependent and a column wise normalization may distort those row wise relations, i.e. shares. In 
those cases, the column wise normalization has to be provided by the user.{p_end}

{title:Compatibility and Multiprocessing}

{p}Except for the {cmd:margin} and {cmd:signal} commands {hi:brain} fully supports older STATA Versions (tested for STATA 13). The before mentioned commands still work for older version
but are limited to a maximum of 11000 input respectively output variables.{p_end}
{p}Given the unclear situation of the inclusion of {hi:openmp} of the different {hi:UNIX} distributions including {hi:MacOS}, the corresponding plugins do not support
multiprocessing. Only the {hi:Windows} plugin benefits from multiprocessing. Please consult the Github page of the author (see below) to enable multiprocessing for the other OS
by locally compiling the source.{p_end}

{title:Performance and Multiprocessing}

{p}{cmd:brain} uses C plugins supporting multiprocessing (the parallel usage of multiple processors/cores). While some of the commands, e.g. {cmd:error}
or {cmd:think}, always benefit from multiple cores, the {cmd:train} command uses multiprocessing only if a batch size larger than 1 is
specified. During training, the observations of a batch are distributed to separate cores. This is possible because the delta vectors derived
from every observation in a batch are independent. Only after the processing of a batch, the vectors will be applied to the weights of the neural
network. By default, the training will use all available processors unless the batch size is smaller than the processor number. For the highest
efficiency, the batch size should be divisible by the number of processors, which can be inquired by calling {cmd:brain} without an option.
Multiprocessing can be deactivated with the option {cmd:sp} (single processing). This can be useful for keeping the etiquette on shared servers or
if some leeway for other applications is needed. If a neural network has only a low number of weights, the overhead imposed by multiprocessing can
lead to a negative effect on performance, especially on machines with only 4 or less cores. It is advised to undertake performance comparisons
between single- and multiprocessing (see Example 2).

{title:Example 1: OLS vs brain on unobserved interaction and polynomials}
{inp}
    clear
    set obs 100
    gen x1 = invnorm(uniform())
    gen x2 = invnorm(uniform())
    gen y = x1 + x2 + x1^2 + x2^2 + x1*x2

    sum y
    scalar ymean = r(mean)
    egen sst = sum((y-ymean)^2)

    reg y x1 x2

    predict yreg
    egen rreg = sum((y-yreg)^2)

    brain define, input(x1 x2) output(y) hidden(10 10)
    brain train, iter(1000) eta(1) sp
    brain think ybrain

    egen rbrain = sum((y-ybrain)^2)

    di "R-squared reg: " 1-rreg/sst
    di "R-sq.   brain: " 1-rbrain/sst
{text}

{title:Example 2: Single- vs. muliprocessing}
{inp}
    clear
    set more off
    set obs 2000
    gen x1 = invnorm(uniform())
    gen x2 = invnorm(uniform())
    gen y = x1 + x2 + x1^2 + x2^2 + x1*x2

    timer clear
    global hidden1 = "10 10"
    global hidden2 = "50 50"

    brain define, input(x1 x2) output(y) hidden($hidden1)
    brain save test
    
    timer on 1
    brain train, iter(500) eta(0.25) batch(16) sp
    timer off 1

    brain load test
    timer on 2
    brain train, iter(500) eta(0.25) batch(16)
    timer off 2

    brain define, input(x1 x2) output(y) hidden($hidden2)
    brain save test

    timer on 3
    brain train, iter(500) eta(0.25) batch(16) sp
    timer off 3

    brain load test
    timer on 4
    brain train, iter(500) eta(0.25) batch(16)
    timer off 4

    timer list
{text}

{title:Example 3: OLS vs brain on non-linear function}
{inp}
    clear
    set obs 200
    gen x = 4*_pi/200 *_n
    gen y = sin(x)

    reg y x
    predict yreg

    brain define, input(x) output(y) hidden(20)
    brain train, iter(1000) eta(1) sp
    brain think ybrain

    twoway (scatter y x, sort) (line yreg x, sort) (line ybrain x, sort)
{text}

{title:Example 4: probit vs brain on binary output variable and application of weights}
{inp}
    sysuse auto, clear
    tab foreign

    probit foreign price-gear_ratio
    predict pforeign
    brain fit foreign pforeign

    brain define, input(price-gear_ratio) output(foreign) hidden(20 20)
    brain train, iter(500) eta(1) best sp
    brain fit foreign

    keep if foreign == 0 | make == "Audi Fox" // extremely skewed distribution (only one foreign car)
    tab foreign

    brain define, input(price-gear_ratio) output(foreign) hidden(10)
    brain train, iter(500) eta(1) best sp // not weighted: predicting the outlier provides almost no benefit
    brain fit foreign

    gen w = 1
    sum foreign
    replace w = (1-r(mean))/r(mean) if foreign == 1

    brain define, input(price-gear_ratio) output(foreign) hidden(10)
    brain train [pweight=w], iter(500) eta(1) best sp // weighted: outlier has a large impact on the error
    brain fit foreign
{text}

{title:Example 5: categorical respectively ordinal variables}
{inp}
    sysuse auto, clear
    gen byte t = weight/1000
    tab t, gen(t)
    brain define, input(price-trunk length-foreign) output(t1-t4) hidden(20 20)
    brain train, iter(500) eta(1) best sp
    brain think b1 b2 b3 b4
    brain fit t1 b1
    brain fit t2 b2
    brain fit t3 b3
    brain fit t4 b4
{text}

{title:Example 6: dynamic adjustment of eta during training exploiting the "best" option}
{inp}
    clear
    set obs 100
    gen x1 = invnorm(uniform())
    gen x2 = invnorm(uniform())
    gen y = x1 + x2 + x1^2 + x2^2 + x1*x2

    sum y
    scalar ymean = r(mean)
    egen sst = sum((y-ymean)^2)

    reg y x1 x2
    predict yreg
    egen rreg = sum((y-yreg)^2)

    brain define, input(x1 x2) output(y) hidden(10 10)
    local eta = 20 // For demonstration only. If eta is too large, the training can freeze. Usually you start with 1.
    local half = 1
    local run = 1
    while `run' <= 50 & `half' <= 10  { // exit after 50 improving iteration cycles or after 10 eta halvings
        di as text "RUN " as result `run'
        brain train, iter(100) eta(`eta') best sp
        if r(iter) == 0 { // no improvement to the beginning of the cycle
            local eta = `eta'/2
            local half = `half'+1
        }
        else {
            local run = `run'+1
        }
    }
    brain think ybrain
    egen rbrain = sum((y-ybrain)^2)

    di "R-squared reg: " 1-rreg/sst
    di "R-sq.   brain: " 1-rbrain/sst
{text}

{title:Update History}

{p 0 11}{hi:2021.19.05} The new {hi:norm} command allows for specific normalization of groups of variables.{break}
The {hi:nonorm} option of the {hi:define} command skips nromalization and testing.{break}
New command {hi:reset} re-initilializes the weights of the {hi:brain} without redefining the normalization.{break}
Default {hi:spread} set from 0.5 to 0.25, as specified in the help file.

{p 0 11}{hi:2021.16.02} Recompiled the MAC plugin to exclude {hi:openmp} libraries because of incompatible distributions.

{p 0 11}{hi:2020.12.08} Improved compatibility with older STATA versions (below 15) in terms of matrix sizes.{break}
Fixed a bug that prevented random weight initialization.{break}
Recompiled the UNIX plugin to exclude {hi:openmp} libraries because of incompatible distributions.

{p 0 11}{hi:2020.11.30} Fixed a bug that prevented the usage of the {hi:fit} command without a second variable.{break}
The {hi:fit} function allows the specification of a threshold for binary one.

{p 0 11}{hi:2020.10.07} The {hi:define} paramter {hi:raw} prevents automatic normalization for already normalized data.

{p 0 11}{hi:2020.04.28} Revised documentation and program in regard of proper usage of weights.

{p 0 11}{hi:2020.03.11} All matrices can exceed matsize limitations by taking a detour over mata.{break}
The brain matrix fragmentation of the former solution (2020.03.02) is obsolete.{break}
The brain, load and save commands additionally verify the integrity of the matrix structure.

{p 0 11}{hi:2020.03.02} Replaced all mata components with C plugins supporting multiprocessing.{break}
The network can exceed the maximum matrix size of Stata.{break}
Syntax errors are now more consistent.

{p 0 11}{hi:2019.11.13} The commands {hi:train} and {hi:error} support weights.{break}
New command {hi:fit} calculates recall and precision for binary output.

{p 0 11}{hi:2019.03.22} Implemented {hi:batch} training.{break}
Changed training ouput to interval reports of real absolute errors instead of intermediate errors.{break}
{hi:nosort} is now called {hi:noshuffle} as shuffling is now applied before every iteration.{break}
The {hi:best} option alway picks the best intermediate result in case of alternating errors.{break}
New command {hi:error} reports the overall absolute error instead of using the {hi:train} command with {hi:iter(0)}.{break}
{hi:signal} now works as intended.

{p 0 11}{hi:2018.11.21} Initial version.

{title:Acknowledgements}

I thank my colleague {hi:Robert Braeutigam} for facilitating the Unix and Mac plugin versions.

{title:Author}

{p 4 4}Thorsten Doherr{break}
Centre for European Economic Research{break}
L7,1{break}
68161 Mannheim{break}
Germany{break}
E-Mail: doherr@zew.de{break}
Internet: https://www.zew.de{break}
Github: https://github.com/ThorstenDoherr/brain
