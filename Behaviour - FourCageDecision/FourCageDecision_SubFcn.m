classdef FourCageDecision_SubFcn

    properties
    end

    methods(Static)

        function currFile = GetRawData(currFile, SET, IterVar)
            % Get data
            currFile.Trajectory =       readtable([SET.BasePath, SET.Phase{IterVar(1)}, '\', SET.Conditions.cages{IterVar(2)}, '\', currFile.Basename, '_tracked.csv']);
            % Get arena annotation
            currFile.ArenaAnnotation =  readtable([SET.BasePath, SET.Phase{IterVar(1)}, '\', SET.Conditions.cages{IterVar(2)}, '\',  currFile.Basename, '_ArenaAnnotation.csv']);
            % Get mask annotation
            currFile.MasksAnnotation =  readtable([SET.BasePath, SET.Phase{IterVar(1)}, '\', SET.Conditions.cages{IterVar(2)}, '\',  currFile.Basename, '_MasksAnnotation.csv']);
            % Smooth trajectories
            currFile.Trajectory.pos_x = FourCageDecision_SubFcn.smooth(currFile.Trajectory.pos_x, SET.g_hw, SET.g_filter, [], SET.g_sigma)';
            currFile.Trajectory.pos_y = FourCageDecision_SubFcn.smooth(currFile.Trajectory.pos_y, SET.g_hw, SET.g_filter, [], SET.g_sigma)';
        end%FCN:GetRawData

        function [p, s, TestStatDistribution, c] = BootstrapHypothesisTesting(xSample, z, y, N_Boot, seed, nComparisons, userTestStat)
            % [p, s, TestStatDistribution, c] = BootstrapHypothesisTesting(xSample, z, y, N_Boot, seed, userTestStat)
            % Bootstrap-based randomization test for statistical inference on either
            % one-sample or two-sample data.
            %
            % 'one-sample'
            % -------------------------------------------------------------------------
            % A one-sample test can be used to determine whether the mean a given
            % sample differs from a pre-determined value (e.g. 0.5).
            % The default test statistic is |avg-PredetVal| / (std/N);
            % Inputs:
            %   xSample = 'one-sample'
            %   z ................ original sample
            %   y ................ pre-determined value. Default is 0
            %   N_Boot ........... number of resampling. Default is 5000
            %   seed ............. seed for reproducibility. Default is 1234
            %   userTestStat ..... custom test statistic with three inputs: (i) sample,
            %                      (ii) sample size, and (iii) pre-determined value
            %
            % 'two-sample'
            % -------------------------------------------------------------------------
            % A two-sample test can be used to determine whether the means of two given
            % samples differ from each other
            % The default test statistic is |avg1-avg2| / sqrt(std1/N1 + std2/N2);
            % Inputs:
            %   xSample = 'two-sample'
            %   z ................ first original sample
            %   y ................ second original sample
            %   N_Boot ........... number of resampling. Default is 5000
            %   seed ............. seed for reproducibility. Default is 1234
            %   userTestStat ..... custom test statistic with four inputs: (i) sample1,
            %                      (ii) sample2, (iii) sample size 1, and (iv) sample
            %                      size 2
            %
            % 'two-sample-pairs'
            % -------------------------------------------------------------------------
            % A two-sample test can be used to determine whether the
            % mean pairwise difference between two samples is different from
            % zero
            % The default test statistic is |avg(z-y)| / sqrt(std1/N1 + std2/N2);
            % Inputs:
            %   xSample = 'two-sample-pairs'
            %   z ................ first original sample
            %   y ................ second original sample
            %   N_Boot ........... number of resampling. Default is 5000
            %   seed ............. seed for reproducibility. Default is 1234
            %   userTestStat ..... custom test statistic with four inputs: (i) sample1,
            %                      (ii) sample2, (iii) sample size 1, and (iv) sample
            %                      size 2
            %
            % 'ranked-consistency'
            % -------------------------------------------------------------------------
            % This can be used to detect differences in treatments across multiple test
            % attempts. The procedure involves ranking each row together, then
            % considering the values of ranks by columns.
            % The default test statistic is 12n/k(k+1) * sum[j=1,k]( (r-(k+1)/2)^2 )
            % Inputs:
            %   xSample = 'ranked-consistency'
            %   z ................ original sample (n*k matrix)
            %   y ................ number of repetitions. Default is 1.
            %   N_Boot ........... number of resampling. Default is 5000
            %   seed ............. seed for reproducibility. Default is 1234
            %   nComparisons ..... number of multiple comarisons. Default
            %                      is 1 if left empty (nComparisons=[]) or
            %                      if smaller than zero
            %   userTestStat ..... custom test statistic with three inputs: (i) n,
            %                      (ii) k, (iii) rank table
            %
            % 'ks-test'
            % -------------------------------------------------------------------------
            % Kolmogorov–Smirnov test comparing two different
            % distributions. The default test statistic
            % is max(abs((cumsum(z,1)./sum(z,1)) - (cumsum(y,1)./sum(y,1))))
            % Inputs:
            %   xSample = 'ks-test'
            %   z ................ first vector
            %   y ................ second vector Default is a shuffled
            %                      version of the original.
            %   N_Boot ........... number of resampling. Default is 5000
            %   seed ............. seed for reproducibility. Default is 1234
            %   userTestStat ..... custom test statistic with two inputs:
            %                      two vectors with counts ber bin
            %
            % Version24-April-2023, Matlab R2023a, Yannick


            % Check number of inputs
            if nargin == 7
                % --- custom test statistic
                TestStat = userTestStat;
            end
            if nargin < 7
                % --- default test statistic
                switch xSample
                    case 'one-sample'
                        TestStat = @(x1, L_x1, PredetVal) abs(mean(x1) - PredetVal) ./ (std(x1) / sqrt(L_x1));
                    case 'two-sample'
                        TestStat = @(x1, x2, L_x1, L_x2) abs(mean(x1) - mean(x2)) ./ sqrt(   var(x1)/L_x1 + var(x2)/L_x2   );
                    case 'two-sample-pairs'
                        TestStat = @(x1, L_x1) abs(mean(x1)) ./ (std(x1) / sqrt(L_x1));
                    case 'ranked-consistency'
                        TestStat = @(n,k,r) ((12*n)/(k*(k+1))) * sum( (r-((k+1)/2)).^2 );
                    case 'ks-test'
                        TestStat = @(h1, h2) max(abs((cumsum(h1,1)./sum(h1,1)) - (cumsum(h2,1)./sum(h2,1))));
                end%switch
            end
            if nargin ==6 && (isempty(nComparisons) || nComparisons<1)
                nComparisons = 1;
            end
            if nargin < 6
                % --- number of multiple comparisons
                nComparisons = 1;
            end
            if nargin < 5
                % --- seed
                seed = 1234;
            end
            if nargin < 4
                % --- number of boot sample
                N_Boot = 5000;
            end
            if nargin < 3
                % --- default comparison
                switch xSample
                    case 'one-sample'
                        y = 0;
                    case 'two-sample'
                        y = randn(size(z));
                    case 'two-sample-pairs'
                        y = zeros(size(z));
                    case 'ranked-consistency'
                        y = 1;
                    case 'ks-test'
                        y = randsample(z,length(z));
                end%switch
            end
            if nargin < 2
                error('Error: Missing input.')
            end



            % Switch whether to perform a one-sample or two-sample bootstrap-based
            %  randomization test
            switch xSample
                case 'one-sample'
                    % Reshape input sample
                    z = z(:);
                    % Get TestStatDistribution to draw from
                    z_tilde = z - mean(z) + y;
                    % Sample from the joined TestStatDistribution
                    rng(seed)
                    z_boot = reshape(z_tilde(randsample(1:length(z), length(z)*N_Boot, 'true')), [length(z), N_Boot]);
                    % Apply test statistic
                    TestStatDistribution.sample = TestStat(z, length(z), y);
                    TestStatDistribution.boot = TestStat(z_boot, length(z), y);
                    % Cohen's d stays empty
                    c = [];
                case 'two-sample'
                    % Reshape input samples
                    z = z(:);
                    y = y(:);
                    % Get joined TestStatDistributions to sample from
                    x = [z;y];
                    % Draw bootstrap samples with replacement
                    rng(seed)
                    x_boot = reshape(randsample(x, length(x)*N_Boot, 'true'), [length(x),N_Boot]);
                    % Split resamples according to length of input samples
                    z_boot = x_boot(1:length(z),:);
                    y_boot = x_boot(length(z)+1:end,:);
                    % Evaluate the test statistics on the original and on the
                    % bootstrap samples
                    TestStatDistribution.sample = TestStat(z,      y,      length(z), length(y));
                    TestStatDistribution.boot =   TestStat(z_boot, y_boot, length(z), length(y));
                    % Get Cohen's d (effect size)
                    c = abs(mean(z)-mean(y)) / std(x);
                case 'two-sample-pairs'
                    % % Reshape input sample
                    % x = z(:)-y(:);
                    % % Get TestStatDistribution to draw from
                    % x_tilde = x - mean(x);
                    % % Sample from the joined TestStatDistribution
                    % rng(seed)
                    % x_boot = reshape(x_tilde(randsample(1:length(z), length(z)*N_Boot, 'true')), [length(z), N_Boot]);
                    % % Apply test statistic
                    % TestStatDistribution.sample = TestStat(x, length(x));
                    % TestStatDistribution.boot = TestStat(x_boot, size(x_boot,1));
                    % % Get Cohen's d (effect size)
                    % c = abs(mean(z)-mean(y)) / std(x);

                    % Get TestStatDistribution to draw from
                    test_distr = [z(:); y(:)];
                    % Resample
                    rng(seed)
                    z_boot = reshape(test_distr(randsample(1:length(z), length(z)*N_Boot, 'true')), [length(z), N_Boot]);
                    rng(seed+1)
                    y_boot = reshape(test_distr(randsample(1:length(y), length(y)*N_Boot, 'true')), [length(y), N_Boot]);
                    % Get pairwise differences
                    x = z(:)-y(:);
                    x_boot = z_boot-y_boot;
                    % Apply test statistic
                    TestStatDistribution.sample = TestStat(x, length(x));
                    TestStatDistribution.boot = TestStat(x_boot, size(x_boot,1));
                    % Get Cohen's d (effect size)
                    c = abs(mean(z)-mean(y)) / std(x);

                case 'ranked-consistency'
                    % Get info on sample
                    [sample_r, sample_c] = size(z);
                    % Check correct input
                    if (y>1)
                        sample_r = sample_r/y;
                        if (floor(sample_r) ~= sample_r)
                            error('Error: The number of rows must be a multiple of y');
                        end
                    end
                    % Get a matrix of ranks m.  For the unusual case of replicated
                    % measurements, rank together all replicates in the same row.  This
                    % is the advice given by Zar (1996), "Biostatistical Analysis."
                    m = z;
                    for j=1:sample_r
                        jrows = y * (j-1) + (1:y);
                        v = z(jrows,:);
                        a = tiedrank(v(:));
                        m(jrows,:) = reshape(a, y, sample_c);
                        clear a v jrows
                    end
                    % Get the average rank
                    avgRank = mean(m);
                    % Evaluate the test statistics on the original
                    TestStatDistribution.sample = TestStat(size(z,1), size(z,2), avgRank);
                    % Evaluate the test statistics on permutated data
                    % --- Preallocation
                    TestStatDistribution.boot = nan(N_Boot,1);
                    % Repeat N_Boot times
                    for iBoot = 1:N_Boot
                        z_boot = reshape(randsample(z(:), numel(z), 'true'), [size(z,1), size(z,2)]);
                        % Get a matrix of ranks m.  For the unusual case of replicated
                        % measurements, rank together all replicates in the same row.  This
                        % is the advice given by Zar (1996), "Biostatistical Analysis."
                        m = z_boot;
                        for j=1:sample_r
                            jrows = y * (j-1) + (1:y);
                            v = z_boot(jrows,:);
                            a = tiedrank(v(:));
                            m(jrows,:) = reshape(a, y, sample_c);
                            clear a v jrows
                        end
                        % Get the average rank
                        avgRank = mean(m);
                        TestStatDistribution.boot(iBoot) = TestStat(size(z,1), size(z,2), avgRank);
                    end%iBoot
                    % Cohen's d stays empty
                    c = [];
                case 'ks-test'
                    % Reshape input samples
                    z = z(:);
                    y = y(:);
                    % Get joined count to sample from
                    x = sum([z,y],2);
                    % Draw bootstrap samples
                    z_boot = zeros(length(z),N_Boot);
                    y_boot = zeros(length(y),N_Boot);
                    for iBin = 1:length(x)
                        rng(seed)
                        if x(iBin) == 0
                            z_boot(iBin,:) = zeros(1,N_Boot);
                        else
                            z_boot(iBin,:) = randsample(0:x(iBin), N_Boot, true);
                        end
                        y_boot(iBin,:) = x(iBin)-z_boot(iBin,:);
                    end
                    % Evaluate the test statistics on the original and on the
                    % bootstrap samples
                    TestStatDistribution.sample = TestStat(z,      y);
                    TestStatDistribution.boot =   TestStat(z_boot, y_boot);
                    % Cohen's d stays empty
                    c = [];
                otherwise
                    error('Error: Unknown test (xSample)')
            end%switch

            % Get p value
            p = mean(TestStatDistribution.boot >= TestStatDistribution.sample);
            % Check wether p value does not exeed boundaries.
            if p == 0
                p = 1/N_Boot;
                warning('Test resulted in p=0. Thus it was set to 1/N_Boot.')
            elseif p < 1/N_Boot
                p = 1/N_Boot;
                warning('Test resulted in p<1/N_Boot. Thus it was set to 1/N_Boot.')
            end
            % Correct p value for multiple comparisons
            p = p * nComparisons;
            % Get Shannon information
            s = -log2(p);
        end%FCN:BootstrpHypothesisTesting


        function [smoothed_signal, g] = smooth(signal, hw, kernel, tau, sigma)
            % SMOOTH(signal, hw, g_filter, tau, sigma) filters a given vector 'signal'
            % by calculating the running average, if no explecit  filter function is
            % set. Via 'kernel' the running averages can be replaced by one of the
            % following kernels:
            %   - Gaussian:             g_filter = 'gauss'          (needs specification of one value in'sigma'; e.g. hw/3 to get the 95% area under the curve with 2*sigma)
            %   - Mexican hat:          g_filter = 'mexhat'         (needs specification of two values in'sigma'; e.g. [hw/6; hw/3])
            %   - Exp. Decay:           g_filter = 'exp_decay'      (needs specification of a time constant 'tau'; e.g. tau=2)
            %   - Inverted Exp. Decay:  g_gilter = 'inv_exp_decay'  (needs specification of a time constant 'tau'; e.g. tau=2)
            %   - Gabor Wavelet(even):  g_filter = 'gabor_even'     (needs specification of one value in'sigma'; e.g. hw/3 to get the 95% area under the curve with 2*sigma)
            %   - Gabor Wavelet(odd):   g_filter = 'gabor_odd'      (needs specification of one value in'sigma'; e.g. hw/3 to get the 95% area under the curve with 2*sigma)
            % The half width by which the input should be filtered can be set via the
            % variable 'hw'.
            % Version: 07-Feb-2021

            % Check number of inputs. If only three inputs are given, use a simple
            % running avergae to filter the data.
            if nargin < 3
                % Running average
                width = 2*hw+1;
                g = 1/width * ones(1,width);
            else
                switch kernel
                    %---- Gaussian ----------------------------------------------------
                    case 'gauss'
                        x = -hw:hw;
                        sigma=hw/3;% hw/3 --> to get the 95% area under the curve with 2*sigma
                        g = normpdf(x, 0, sigma);
                        % The kernel's integral should be equal to one to prevent on
                        % unintended amplification of the data
                        g = g/sum(g);
                        %---- Mexican hat -------------------------------------------------
                    case 'mexhat'
                        x = -hw:hw;
                        g1 = normpdf(x, 0, sigma(1));
                        g2 = -normpdf(x, 0, sigma(2));
                        g = g1+g2;
                        % The kernel's integral should be equal to zero to prevent on
                        % unintended amplification of the data
                        g = g-(sum(g)/length(g));
                        %---- Exp. Decay --------------------------------------------------
                    case 'exp_decay'
                        x = -hw:hw;
                        e = ones(1,length(x))*exp(1);
                        g = e.^(-x/tau);
                        g(x<0) = 0;
                        % The kernel's integral should be equal to one to prevent on
                        % unintended amplification of the data
                        g = g/sum(g);
                        %---- Inverted Exp. Decay -----------------------------------------
                    case 'inv_exp_decay'
                        x = -hw:hw;
                        e = ones(1,length(x))*exp(1);
                        tau = 2;
                        g = e.^(-x/tau);
                        g(x<0) = 0;
                        % The kernel's integral should be equal to one to prevent on
                        % unintended amplification of the data
                        g = g/sum(g);
                        g = [g(x<0),fliplr(g(x>=0))];
                        %---- Gabor Wavelet(even) -----------------------------------------
                    case 'gabor_even'
                        x = -hw:hw;
                        T = sigma - sigma/100;
                        g = normpdf(x, 0, sigma);
                        g = g.*cos( ((2*pi)/T)*(x+1));
                        % The kernel's integral should be equal to zero to prevent on
                        % unintended amplification of the data
                        g = g-(sum(g)/length(g));
                        %---- Gabor Wavelet(odd) ------------------------------------------
                    case 'gabor_odd'
                        x = -hw:hw;
                        T = sigma - sigma/100;
                        g = normpdf(x, 0, sigma);
                        g = g.*sin( ((2*pi)/T)*(x+1));
                        % The kernel's integral should be equal to zero to prevent on
                        % unintended amplification of the data
                        g = g-(sum(g)/length(g));
                end
            end
            % Preallocate with correct vector orientation
            signal = reshape(signal,[1,length(signal)]);
            signal =[ones(1,hw)*signal(1), signal, ones(1,hw)*signal(end)];
            smoothed_signal = reshape(signal,[1,length(signal)]);
            g = fliplr(g);
            % Smooth signal
            for i = hw+1:length(signal)-(hw+1)
                smoothed_signal(i) = sum(signal(i-hw:i+hw).*g);
            end
            %flip g again for output
            g = fliplr(g);
            % Cut signal
            smoothed_signal=smoothed_signal(hw+1:end-(hw));
        end%FCN:smooth

        function currFile = GetConditionOrder(currFile, CondNames)
            % Iterate over cage conditions and get row in annotation
            for iCond = 1:length(CondNames)
                helper = strfind(currFile.Basename, CondNames{iCond});
                Cond_Idx(iCond) = helper(1);
            end%iCond
            % Sort by appearence
            [~, CondAnnotation_Idx] = sort(Cond_Idx);
            % Save info
            currFile.Cages = {};
            for iCond = 1:length(CondNames)
                currFile.Cages{iCond} = CondNames{CondAnnotation_Idx(iCond)};
            end%iCond
        end%FCN:GetConditionOrder

        function currFile = CenterNormData(currFile)
            % --- Center data to (0, 0)
            currFile.Trajectory.pos_x = currFile.Trajectory.pos_x - currFile.ArenaAnnotation.x;
            currFile.Trajectory.pos_y = currFile.Trajectory.pos_y - currFile.ArenaAnnotation.y;
            currFile.MasksAnnotation.x = currFile.MasksAnnotation.x - currFile.ArenaAnnotation.x;
            currFile.MasksAnnotation.y = currFile.MasksAnnotation.y - currFile.ArenaAnnotation.y;
            % --- Normalize data to -1 and 1
            currFile.Trajectory.pos_x = currFile.Trajectory.pos_x / currFile.ArenaAnnotation.r;
            currFile.Trajectory.pos_y = currFile.Trajectory.pos_y / currFile.ArenaAnnotation.r;
            currFile.MasksAnnotation.x = currFile.MasksAnnotation.x / currFile.ArenaAnnotation.r;
            currFile.MasksAnnotation.y = currFile.MasksAnnotation.y / currFile.ArenaAnnotation.r;
            currFile.MasksAnnotation.r = currFile.MasksAnnotation.r / currFile.ArenaAnnotation.r;
        end%FCN:CenterNormData

        function currFile = SpeedProfile(currFile)
            helper = [gradient(currFile.Trajectory.pos_x), gradient(currFile.Trajectory.pos_x)];
            currFile.SpeedProfile = sqrt(sum(helper'.*helper'))';
        end%FCN:SpeedProfile

        function currFile = PizzaHeatMap(currFile, SET)
            % Keep raw data
            rawData = [currFile.Trajectory.pos_x, currFile.Trajectory.pos_y];
            % Iterate over conditions and arrange them in CCW order:
            % 0      deg:    Ctr
            % 90     deg:    Leaves
            % 270    deg:    Lo
            % +180   deg:    LoLeaves
            SET.RotAngeles = [0 90 270 180];
            for iCond = 1:length(SET.Cages)
                % Generate data structure
                currFile.Pizza.(SET.Cages{iCond}(2:end-1)) = [];
                % Get position of current cage
                idx = find(strcmp(currFile.Cages, SET.Cages{iCond}));
                CagePos = [currFile.MasksAnnotation.x(idx), currFile.MasksAnnotation.y(idx)];
                % Get angle of current cage
                CageAngle = atan2d(CagePos(2), CagePos(1));
                % Create rotation matrix to rotate to zero
                M = [cosd(-CageAngle) -sind(-CageAngle);
                    sind(-CageAngle)  cosd(-CageAngle)];
                % Rotate by multiplication with M
                rawData_rot = (M*rawData(:,1:2)')';
                % 2D-binning of raw data
                pos_2D = hist3([rawData_rot(:,2), rawData_rot(:,1)], 'ctrs', {linspace(-1, 1, SET.HeatMapGrid) linspace(-1, 1, SET.HeatMapGrid)});
                % Get animal density
                baseline_max = zeros(SET.HeatMapGrid,SET.HeatMapGrid);
                baseline_max(floor(SET.HeatMapGrid/2), floor(SET.HeatMapGrid/2))=1;
                baseline_max = imgaussfilt(baseline_max, SET.SmoothValue, 'FilterDomain', 'spatial', 'FilterSize', SET.HeatMapGrid-1);
                baseline_max = max(max(baseline_max));
                density2D = imgaussfilt(pos_2D, SET.SmoothValue, 'FilterDomain', 'spatial', 'FilterSize', SET.HeatMapGrid-1)/baseline_max/size(rawData_rot,1);
                % Kick off toppings not belonging onto the current slice
                % --- Get angles
                rot_Angles = abs(atan2d(rawData_rot(:,2), rawData_rot(:,1)));
                % --- Get data points exceeding range
                KickOff = find(rot_Angles>SET.HeatmapSliceSize);
                % --- Kick off topings
                rawData_rot(KickOff,:) = [];
                % Continue if some data points are left over
                if ~isempty(rawData_rot)
                    % Create rotation matrix to rotate to correct position
                    M = [cosd(SET.RotAngeles(iCond)) -sind(SET.RotAngeles(iCond));
                        sind(SET.RotAngeles(iCond))  cosd(SET.RotAngeles(iCond))];
                    % Rotate by multiplication with M
                    rawData_rot = (M*rawData_rot(:,1:2)')';
                    % Save pizza slice
                    currFile.Pizza.(SET.Cages{iCond}(2:end-1)) = rawData_rot;
                end%if
                % Do the same for the pizza
                vec = linspace(-1, 1, SET.HeatMapGrid);
                [idx_c, idx_r] = find(density2D>-inf);
                pixelAngle = atan2d(vec(idx_c), vec(idx_r));
                KickOff = find(abs(pixelAngle)>SET.HeatmapSliceSize);
                density2D(KickOff) = NaN;
                % Rotate in place
                density2D = imrotate(density2D, SET.RotAngeles(iCond));
                currFile.PizzaDensity.(SET.Cages{iCond}(2:end-1)) = density2D;
                % Also get the desnity at the center of the cage
                % --- get location of cage
                v = [cosd(SET.RotAngeles(iCond)), sind(-SET.RotAngeles(iCond))];
                p = floor(v*(SET.HeatMapGrid/2)*norm(CagePos)+(SET.HeatMapGrid/2));
                % --- get density at the location
                currFile.CageDensity.(SET.Cages{iCond}(2:end-1)) = density2D(p(2),p(1));
            end%iCond
        end%FCN:PizzaHeatMap

        function currFile = RotData(currFile, ZeroCond)
            % Get raw data
            rawData = [currFile.Trajectory.pos_x, currFile.Trajectory.pos_y];
            % Get position of the LoLeavesZCo cage
            idx = find(strcmp(currFile.Cages, ZeroCond));
            CagePos = [currFile.MasksAnnotation.x(idx), currFile.MasksAnnotation.y(idx)];
            % Get angle
            CageAngle = atan2d(CagePos(2), CagePos(1));
            % Create rotation matrix to rotate to zero
            M = [cosd(-CageAngle) -sind(-CageAngle);
                sind(-CageAngle)  cosd(-CageAngle)];
            % Rotate by multiplication with M
            rawData_rot = (M*rawData(:,1:2)')';
            % Copy back rotated data
            currFile.Trajectory.pos_x = rawData_rot(:,1);
            currFile.Trajectory.pos_y = rawData_rot(:,2);
        end%FCN:RotData

        function currFile = Dist2Cage(currFile, CondNames)
            % Get raw data
            rawData = [currFile.Trajectory.pos_x, currFile.Trajectory.pos_y];
            % Iterate over conditions
            for iCond = 1:length(CondNames)
                % Get position of current cage
                idx = find(strcmp(currFile.Cages, CondNames{iCond}));
                CagePos = [currFile.MasksAnnotation.x(idx), currFile.MasksAnnotation.y(idx)];
                % Get distance to cage
                helper = rawData - CagePos;
                currFile.Dist2Cage(:,iCond) = sqrt(sum(helper'.*helper'))';
            end%iCond
        end%FCN:Dist2Cage

        function currFile = AtCage(currFile, SET, CondNames)
            % Get raw data
            rawData = currFile.Dist2Cage;
            % Iterate over conditions
            for iCond = 1:length(CondNames)
                % Get position of current cage
                idx = find(strcmp(currFile.Cages, CondNames{iCond}));
                CageRadius = currFile.MasksAnnotation.r(idx);
                % Add tolerance radius
                CageRadius = CageRadius + SET.ToleranceDistance*(2/SET.dArena);
                % Check whether within
                temp = rawData(:,iCond)<CageRadius;
                % Correct visits
                temp = FourCageDecision_SubFcn.CorrectVisits(temp, SET);
                % Save
                currFile.AtCage(:,iCond) = temp;
            end%iCond
        end%FCN:Dist2Cage

        function beeswarmplot_advanced(BeeData, pos, width, properties)
            % BEESWARMPLOT_ADVANCED(BeeData, pos, width, properties)  creates a
            % beeswarm plot , i.e. point distributions where jitter has been added to
            % the x-position of the data points to avoid overlap.
            % INPUTS:
            %      - 'BeeData':     1D vector of numbers
            %      - 'pos':         x-value(vertical plot) or y-value(horizontal plot)
            %                       at which the plot should be located
            %      - 'width':       Total width of the swarm.
            %      - 'properties':  Properties which specify how the swarm should look
            %                       like
            % DEFAULT PROPERTIES:
            %       PROPERTY                        DEFAULT VALUE       DESCRIPTION
            %       -----------------------------------------------------------------------------------------------------------------------------------------------------
            %       properties.Orientation =        'vertical'          %(Set how the box plot should be oriented 'vertical' or 'horizontal')
            %       properties.MarkerType =         'o'                 %(Marker type)
            %       properties.MarkerFaceColor =    'k'                 %(Marker face color)
            %       properties.MarkerEdgeColor =    'none'              %(Marker edge color)
            %       properties.MarkerSize =         1                   %(Marker size)
            % Version: 12-May-2020; Yannick (MATLAB 2020a)

            % ----- Prepare data -----
            % Replace not given property values by defaults
            if nargin < 4
                properties = 'default';
            end
            properties = FourCageDecision_SubFcn.FillEmptySwarmPropertyValues(properties);
            % Exclude NaNs
            data.all = BeeData(~isnan(BeeData));
            % reshape
            data.all = reshape(data.all, [length(data.all),1]);
            % Get length of input
            data.N_Bees = length(data.all);
            % Get range of data
            data.range = range(data.all);
            % Sort data
            data.all = sort(data.all);
            % ----- Use the data's density to spread it -----
            % Get the probability density estimate for the sample data
            [density, value] = ksdensity(data.all, 'NumPoints', data.N_Bees*2);
            % Scale data
            density = density/max(density);
            % Cut density to be the min and max of the original data
            xVec = interp1(value, density, data.all);
            % Get the spread
            spreadVec = width*(rand(data.N_Bees,1)-0.5).*xVec;
            spreadVec = spreadVec+pos;
            % Plot spread
            switch properties.Orientation
                case 'vertical'
                    plot(spreadVec, data.all, properties.MarkerType,...
                        'MarkerFaceColor', properties.MarkerFaceColor,...
                        'MarkerEdgeColor', properties.MarkerEdgeColor,...
                        'MarkerSize', properties.MarkerSize)
                case 'horizontal'
                    plot(data.all, spreadVec,...
                        properties.MarkerType,...
                        'MarkerFaceColor', properties.MarkerFaceColor,...
                        'MarkerEdgeColor', properties.MarkerEdgeColor,...
                        'MarkerSize', properties.MarkerSize)
            end%switch orientation
        end%FCN:beeswarmplot_advanced

        function out = FillEmptySwarmPropertyValues(properties)
            % FillEmptyPropertyValues(properties) checks whether a property has been
            % set by the user. If not, replace it by its default value. If no property
            % value has been set, completely use defaults.
            % Set default values
            default.BinSize =            0.1;                 %(Value between 0 and 1 to evenly bin the range of the data. Leave empty for automatic binning)
            default.Orientation =        'vertical';          %(Set how the box plot should be oriented 'vertical' or 'horizontal')
            default.MarkerType =         'o';                 %(Marker type)
            default.MarkerFaceColor =    'k';                 %(Marker face color)
            default.MarkerEdgeColor =    'none';              %(Marker edge color)
            default.MarkerSize =         1;                 %(Marker size)
            % If the user has not given any property, completely use the default
            % settings. Alternatively, check for missing property values and fill gaps
            % with default values
            if strcmp(properties, 'default')
                out = default;
            else
                % Get field names in order to be able to iterate over each property to
                % check whether it has been given by the user
                FieldNames = fieldnames(default);
                % Iterate over all field names and check whether to fill a gap or not
                for iProp = 1:length(FieldNames)
                    if ~isfield(properties, FieldNames{iProp})
                        out.(FieldNames{iProp}) = default.(FieldNames{iProp});
                    else
                        out.(FieldNames{iProp}) = properties.(FieldNames{iProp});
                    end%if prperty has not been set
                end%iProp

            end%if completely use default values
        end%FCN:FillEmptySwarmPropertyValues

        function out = CorrectVisits(data, SET)
            % Prepare output
            out = data;
            % Identify bouts and get some information
            stay_label = bwlabel(out);
            stay_props  = regionprops(stay_label);
            % Identify gaps between bouts and get some information
            gap_label = bwlabel(~out);
            gap_props  = regionprops(gap_label);
            % Start with correcting gaps
            if length(unique(stay_label))>1
                % --- Differentiate between trials starting with bouts and thos
                %     starting with exploration
                if gap_props(1).Centroid(2)<stay_props(1).Centroid(2)
                    for iGap = 2:length(gap_props)
                        if gap_props(iGap).BoundingBox(end) < SET.minInterBoutInterval
                            out(find(gap_label == iGap)) = 1;
                        end%if
                    end%iGap
                else
                    for iGap = 1:length(gap_props)
                        if gap_props(iGap).BoundingBox(end) < SET.minInterBoutInterval
                            out(find(gap_label == iGap)) = 1;
                        end%if
                    end%iGap
                end%if
            end
            % Identify bouts and get some information
            stay_label = bwlabel(out);
            stay_props  = regionprops(stay_label);
            % Now correct bouts that are too short
            for iStay = 1:length(stay_props)
                if stay_props(iStay).BoundingBox(end) < SET.minBoutDuration
                    out(find(stay_label == iStay)) = 0;
                end%if
            end%iGap
        end%FCN:CorrectVisits

        function [cm_data]=ColMapMagma(m)
            cm = [[  1.46159096e-03,   4.66127766e-04,   1.38655200e-02],
                [  2.25764007e-03,   1.29495431e-03,   1.83311461e-02],
                [  3.27943222e-03,   2.30452991e-03,   2.37083291e-02],
                [  4.51230222e-03,   3.49037666e-03,   2.99647059e-02],
                [  5.94976987e-03,   4.84285000e-03,   3.71296695e-02],
                [  7.58798550e-03,   6.35613622e-03,   4.49730774e-02],
                [  9.42604390e-03,   8.02185006e-03,   5.28443561e-02],
                [  1.14654337e-02,   9.82831486e-03,   6.07496380e-02],
                [  1.37075706e-02,   1.17705913e-02,   6.86665843e-02],
                [  1.61557566e-02,   1.38404966e-02,   7.66026660e-02],
                [  1.88153670e-02,   1.60262753e-02,   8.45844897e-02],
                [  2.16919340e-02,   1.83201254e-02,   9.26101050e-02],
                [  2.47917814e-02,   2.07147875e-02,   1.00675555e-01],
                [  2.81228154e-02,   2.32009284e-02,   1.08786954e-01],
                [  3.16955304e-02,   2.57651161e-02,   1.16964722e-01],
                [  3.55204468e-02,   2.83974570e-02,   1.25209396e-01],
                [  3.96084872e-02,   3.10895652e-02,   1.33515085e-01],
                [  4.38295350e-02,   3.38299885e-02,   1.41886249e-01],
                [  4.80616391e-02,   3.66066101e-02,   1.50326989e-01],
                [  5.23204388e-02,   3.94066020e-02,   1.58841025e-01],
                [  5.66148978e-02,   4.21598925e-02,   1.67445592e-01],
                [  6.09493930e-02,   4.47944924e-02,   1.76128834e-01],
                [  6.53301801e-02,   4.73177796e-02,   1.84891506e-01],
                [  6.97637296e-02,   4.97264666e-02,   1.93735088e-01],
                [  7.42565152e-02,   5.20167766e-02,   2.02660374e-01],
                [  7.88150034e-02,   5.41844801e-02,   2.11667355e-01],
                [  8.34456313e-02,   5.62249365e-02,   2.20755099e-01],
                [  8.81547730e-02,   5.81331465e-02,   2.29921611e-01],
                [  9.29486914e-02,   5.99038167e-02,   2.39163669e-01],
                [  9.78334770e-02,   6.15314414e-02,   2.48476662e-01],
                [  1.02814972e-01,   6.30104053e-02,   2.57854400e-01],
                [  1.07898679e-01,   6.43351102e-02,   2.67288933e-01],
                [  1.13094451e-01,   6.54920358e-02,   2.76783978e-01],
                [  1.18405035e-01,   6.64791593e-02,   2.86320656e-01],
                [  1.23832651e-01,   6.72946449e-02,   2.95879431e-01],
                [  1.29380192e-01,   6.79349264e-02,   3.05442931e-01],
                [  1.35053322e-01,   6.83912798e-02,   3.14999890e-01],
                [  1.40857952e-01,   6.86540710e-02,   3.24537640e-01],
                [  1.46785234e-01,   6.87382323e-02,   3.34011109e-01],
                [  1.52839217e-01,   6.86368599e-02,   3.43404450e-01],
                [  1.59017511e-01,   6.83540225e-02,   3.52688028e-01],
                [  1.65308131e-01,   6.79108689e-02,   3.61816426e-01],
                [  1.71713033e-01,   6.73053260e-02,   3.70770827e-01],
                [  1.78211730e-01,   6.65758073e-02,   3.79497161e-01],
                [  1.84800877e-01,   6.57324381e-02,   3.87972507e-01],
                [  1.91459745e-01,   6.48183312e-02,   3.96151969e-01],
                [  1.98176877e-01,   6.38624166e-02,   4.04008953e-01],
                [  2.04934882e-01,   6.29066192e-02,   4.11514273e-01],
                [  2.11718061e-01,   6.19917876e-02,   4.18646741e-01],
                [  2.18511590e-01,   6.11584918e-02,   4.25391816e-01],
                [  2.25302032e-01,   6.04451843e-02,   4.31741767e-01],
                [  2.32076515e-01,   5.98886855e-02,   4.37694665e-01],
                [  2.38825991e-01,   5.95170384e-02,   4.43255999e-01],
                [  2.45543175e-01,   5.93524384e-02,   4.48435938e-01],
                [  2.52220252e-01,   5.94147119e-02,   4.53247729e-01],
                [  2.58857304e-01,   5.97055998e-02,   4.57709924e-01],
                [  2.65446744e-01,   6.02368754e-02,   4.61840297e-01],
                [  2.71994089e-01,   6.09935552e-02,   4.65660375e-01],
                [  2.78493300e-01,   6.19778136e-02,   4.69190328e-01],
                [  2.84951097e-01,   6.31676261e-02,   4.72450879e-01],
                [  2.91365817e-01,   6.45534486e-02,   4.75462193e-01],
                [  2.97740413e-01,   6.61170432e-02,   4.78243482e-01],
                [  3.04080941e-01,   6.78353452e-02,   4.80811572e-01],
                [  3.10382027e-01,   6.97024767e-02,   4.83186340e-01],
                [  3.16654235e-01,   7.16895272e-02,   4.85380429e-01],
                [  3.22899126e-01,   7.37819504e-02,   4.87408399e-01],
                [  3.29114038e-01,   7.59715081e-02,   4.89286796e-01],
                [  3.35307503e-01,   7.82361045e-02,   4.91024144e-01],
                [  3.41481725e-01,   8.05635079e-02,   4.92631321e-01],
                [  3.47635742e-01,   8.29463512e-02,   4.94120923e-01],
                [  3.53773161e-01,   8.53726329e-02,   4.95501096e-01],
                [  3.59897941e-01,   8.78311772e-02,   4.96778331e-01],
                [  3.66011928e-01,   9.03143031e-02,   4.97959963e-01],
                [  3.72116205e-01,   9.28159917e-02,   4.99053326e-01],
                [  3.78210547e-01,   9.53322947e-02,   5.00066568e-01],
                [  3.84299445e-01,   9.78549106e-02,   5.01001964e-01],
                [  3.90384361e-01,   1.00379466e-01,   5.01864236e-01],
                [  3.96466670e-01,   1.02902194e-01,   5.02657590e-01],
                [  4.02547663e-01,   1.05419865e-01,   5.03385761e-01],
                [  4.08628505e-01,   1.07929771e-01,   5.04052118e-01],
                [  4.14708664e-01,   1.10431177e-01,   5.04661843e-01],
                [  4.20791157e-01,   1.12920210e-01,   5.05214935e-01],
                [  4.26876965e-01,   1.15395258e-01,   5.05713602e-01],
                [  4.32967001e-01,   1.17854987e-01,   5.06159754e-01],
                [  4.39062114e-01,   1.20298314e-01,   5.06555026e-01],
                [  4.45163096e-01,   1.22724371e-01,   5.06900806e-01],
                [  4.51270678e-01,   1.25132484e-01,   5.07198258e-01],
                [  4.57385535e-01,   1.27522145e-01,   5.07448336e-01],
                [  4.63508291e-01,   1.29892998e-01,   5.07651812e-01],
                [  4.69639514e-01,   1.32244819e-01,   5.07809282e-01],
                [  4.75779723e-01,   1.34577500e-01,   5.07921193e-01],
                [  4.81928997e-01,   1.36891390e-01,   5.07988509e-01],
                [  4.88088169e-01,   1.39186217e-01,   5.08010737e-01],
                [  4.94257673e-01,   1.41462106e-01,   5.07987836e-01],
                [  5.00437834e-01,   1.43719323e-01,   5.07919772e-01],
                [  5.06628929e-01,   1.45958202e-01,   5.07806420e-01],
                [  5.12831195e-01,   1.48179144e-01,   5.07647570e-01],
                [  5.19044825e-01,   1.50382611e-01,   5.07442938e-01],
                [  5.25269968e-01,   1.52569121e-01,   5.07192172e-01],
                [  5.31506735e-01,   1.54739247e-01,   5.06894860e-01],
                [  5.37755194e-01,   1.56893613e-01,   5.06550538e-01],
                [  5.44015371e-01,   1.59032895e-01,   5.06158696e-01],
                [  5.50287252e-01,   1.61157816e-01,   5.05718782e-01],
                [  5.56570783e-01,   1.63269149e-01,   5.05230210e-01],
                [  5.62865867e-01,   1.65367714e-01,   5.04692365e-01],
                [  5.69172368e-01,   1.67454379e-01,   5.04104606e-01],
                [  5.75490107e-01,   1.69530062e-01,   5.03466273e-01],
                [  5.81818864e-01,   1.71595728e-01,   5.02776690e-01],
                [  5.88158375e-01,   1.73652392e-01,   5.02035167e-01],
                [  5.94508337e-01,   1.75701122e-01,   5.01241011e-01],
                [  6.00868399e-01,   1.77743036e-01,   5.00393522e-01],
                [  6.07238169e-01,   1.79779309e-01,   4.99491999e-01],
                [  6.13617209e-01,   1.81811170e-01,   4.98535746e-01],
                [  6.20005032e-01,   1.83839907e-01,   4.97524075e-01],
                [  6.26401108e-01,   1.85866869e-01,   4.96456304e-01],
                [  6.32804854e-01,   1.87893468e-01,   4.95331769e-01],
                [  6.39215638e-01,   1.89921182e-01,   4.94149821e-01],
                [  6.45632778e-01,   1.91951556e-01,   4.92909832e-01],
                [  6.52055535e-01,   1.93986210e-01,   4.91611196e-01],
                [  6.58483116e-01,   1.96026835e-01,   4.90253338e-01],
                [  6.64914668e-01,   1.98075202e-01,   4.88835712e-01],
                [  6.71349279e-01,   2.00133166e-01,   4.87357807e-01],
                [  6.77785975e-01,   2.02202663e-01,   4.85819154e-01],
                [  6.84223712e-01,   2.04285721e-01,   4.84219325e-01],
                [  6.90661380e-01,   2.06384461e-01,   4.82557941e-01],
                [  6.97097796e-01,   2.08501100e-01,   4.80834678e-01],
                [  7.03531700e-01,   2.10637956e-01,   4.79049270e-01],
                [  7.09961888e-01,   2.12797337e-01,   4.77201121e-01],
                [  7.16387038e-01,   2.14981693e-01,   4.75289780e-01],
                [  7.22805451e-01,   2.17193831e-01,   4.73315708e-01],
                [  7.29215521e-01,   2.19436516e-01,   4.71278924e-01],
                [  7.35615545e-01,   2.21712634e-01,   4.69179541e-01],
                [  7.42003713e-01,   2.24025196e-01,   4.67017774e-01],
                [  7.48378107e-01,   2.26377345e-01,   4.64793954e-01],
                [  7.54736692e-01,   2.28772352e-01,   4.62508534e-01],
                [  7.61077312e-01,   2.31213625e-01,   4.60162106e-01],
                [  7.67397681e-01,   2.33704708e-01,   4.57755411e-01],
                [  7.73695380e-01,   2.36249283e-01,   4.55289354e-01],
                [  7.79967847e-01,   2.38851170e-01,   4.52765022e-01],
                [  7.86212372e-01,   2.41514325e-01,   4.50183695e-01],
                [  7.92426972e-01,   2.44242250e-01,   4.47543155e-01],
                [  7.98607760e-01,   2.47039798e-01,   4.44848441e-01],
                [  8.04751511e-01,   2.49911350e-01,   4.42101615e-01],
                [  8.10854841e-01,   2.52861399e-01,   4.39304963e-01],
                [  8.16914186e-01,   2.55894550e-01,   4.36461074e-01],
                [  8.22925797e-01,   2.59015505e-01,   4.33572874e-01],
                [  8.28885740e-01,   2.62229049e-01,   4.30643647e-01],
                [  8.34790818e-01,   2.65539703e-01,   4.27671352e-01],
                [  8.40635680e-01,   2.68952874e-01,   4.24665620e-01],
                [  8.46415804e-01,   2.72473491e-01,   4.21631064e-01],
                [  8.52126490e-01,   2.76106469e-01,   4.18572767e-01],
                [  8.57762870e-01,   2.79856666e-01,   4.15496319e-01],
                [  8.63320397e-01,   2.83729003e-01,   4.12402889e-01],
                [  8.68793368e-01,   2.87728205e-01,   4.09303002e-01],
                [  8.74176342e-01,   2.91858679e-01,   4.06205397e-01],
                [  8.79463944e-01,   2.96124596e-01,   4.03118034e-01],
                [  8.84650824e-01,   3.00530090e-01,   4.00047060e-01],
                [  8.89731418e-01,   3.05078817e-01,   3.97001559e-01],
                [  8.94700194e-01,   3.09773445e-01,   3.93994634e-01],
                [  8.99551884e-01,   3.14616425e-01,   3.91036674e-01],
                [  9.04281297e-01,   3.19609981e-01,   3.88136889e-01],
                [  9.08883524e-01,   3.24755126e-01,   3.85308008e-01],
                [  9.13354091e-01,   3.30051947e-01,   3.82563414e-01],
                [  9.17688852e-01,   3.35500068e-01,   3.79915138e-01],
                [  9.21884187e-01,   3.41098112e-01,   3.77375977e-01],
                [  9.25937102e-01,   3.46843685e-01,   3.74959077e-01],
                [  9.29845090e-01,   3.52733817e-01,   3.72676513e-01],
                [  9.33606454e-01,   3.58764377e-01,   3.70540883e-01],
                [  9.37220874e-01,   3.64929312e-01,   3.68566525e-01],
                [  9.40687443e-01,   3.71224168e-01,   3.66761699e-01],
                [  9.44006448e-01,   3.77642889e-01,   3.65136328e-01],
                [  9.47179528e-01,   3.84177874e-01,   3.63701130e-01],
                [  9.50210150e-01,   3.90819546e-01,   3.62467694e-01],
                [  9.53099077e-01,   3.97562894e-01,   3.61438431e-01],
                [  9.55849237e-01,   4.04400213e-01,   3.60619076e-01],
                [  9.58464079e-01,   4.11323666e-01,   3.60014232e-01],
                [  9.60949221e-01,   4.18323245e-01,   3.59629789e-01],
                [  9.63310281e-01,   4.25389724e-01,   3.59469020e-01],
                [  9.65549351e-01,   4.32518707e-01,   3.59529151e-01],
                [  9.67671128e-01,   4.39702976e-01,   3.59810172e-01],
                [  9.69680441e-01,   4.46935635e-01,   3.60311120e-01],
                [  9.71582181e-01,   4.54210170e-01,   3.61030156e-01],
                [  9.73381238e-01,   4.61520484e-01,   3.61964652e-01],
                [  9.75082439e-01,   4.68860936e-01,   3.63111292e-01],
                [  9.76690494e-01,   4.76226350e-01,   3.64466162e-01],
                [  9.78209957e-01,   4.83612031e-01,   3.66024854e-01],
                [  9.79645181e-01,   4.91013764e-01,   3.67782559e-01],
                [  9.81000291e-01,   4.98427800e-01,   3.69734157e-01],
                [  9.82279159e-01,   5.05850848e-01,   3.71874301e-01],
                [  9.83485387e-01,   5.13280054e-01,   3.74197501e-01],
                [  9.84622298e-01,   5.20712972e-01,   3.76698186e-01],
                [  9.85692925e-01,   5.28147545e-01,   3.79370774e-01],
                [  9.86700017e-01,   5.35582070e-01,   3.82209724e-01],
                [  9.87646038e-01,   5.43015173e-01,   3.85209578e-01],
                [  9.88533173e-01,   5.50445778e-01,   3.88365009e-01],
                [  9.89363341e-01,   5.57873075e-01,   3.91670846e-01],
                [  9.90138201e-01,   5.65296495e-01,   3.95122099e-01],
                [  9.90871208e-01,   5.72706259e-01,   3.98713971e-01],
                [  9.91558165e-01,   5.80106828e-01,   4.02441058e-01],
                [  9.92195728e-01,   5.87501706e-01,   4.06298792e-01],
                [  9.92784669e-01,   5.94891088e-01,   4.10282976e-01],
                [  9.93325561e-01,   6.02275297e-01,   4.14389658e-01],
                [  9.93834412e-01,   6.09643540e-01,   4.18613221e-01],
                [  9.94308514e-01,   6.16998953e-01,   4.22949672e-01],
                [  9.94737698e-01,   6.24349657e-01,   4.27396771e-01],
                [  9.95121854e-01,   6.31696376e-01,   4.31951492e-01],
                [  9.95480469e-01,   6.39026596e-01,   4.36607159e-01],
                [  9.95809924e-01,   6.46343897e-01,   4.41360951e-01],
                [  9.96095703e-01,   6.53658756e-01,   4.46213021e-01],
                [  9.96341406e-01,   6.60969379e-01,   4.51160201e-01],
                [  9.96579803e-01,   6.68255621e-01,   4.56191814e-01],
                [  9.96774784e-01,   6.75541484e-01,   4.61314158e-01],
                [  9.96925427e-01,   6.82827953e-01,   4.66525689e-01],
                [  9.97077185e-01,   6.90087897e-01,   4.71811461e-01],
                [  9.97186253e-01,   6.97348991e-01,   4.77181727e-01],
                [  9.97253982e-01,   7.04610791e-01,   4.82634651e-01],
                [  9.97325180e-01,   7.11847714e-01,   4.88154375e-01],
                [  9.97350983e-01,   7.19089119e-01,   4.93754665e-01],
                [  9.97350583e-01,   7.26324415e-01,   4.99427972e-01],
                [  9.97341259e-01,   7.33544671e-01,   5.05166839e-01],
                [  9.97284689e-01,   7.40771893e-01,   5.10983331e-01],
                [  9.97228367e-01,   7.47980563e-01,   5.16859378e-01],
                [  9.97138480e-01,   7.55189852e-01,   5.22805996e-01],
                [  9.97019342e-01,   7.62397883e-01,   5.28820775e-01],
                [  9.96898254e-01,   7.69590975e-01,   5.34892341e-01],
                [  9.96726862e-01,   7.76794860e-01,   5.41038571e-01],
                [  9.96570645e-01,   7.83976508e-01,   5.47232992e-01],
                [  9.96369065e-01,   7.91167346e-01,   5.53498939e-01],
                [  9.96162309e-01,   7.98347709e-01,   5.59819643e-01],
                [  9.95932448e-01,   8.05527126e-01,   5.66201824e-01],
                [  9.95680107e-01,   8.12705773e-01,   5.72644795e-01],
                [  9.95423973e-01,   8.19875302e-01,   5.79140130e-01],
                [  9.95131288e-01,   8.27051773e-01,   5.85701463e-01],
                [  9.94851089e-01,   8.34212826e-01,   5.92307093e-01],
                [  9.94523666e-01,   8.41386618e-01,   5.98982818e-01],
                [  9.94221900e-01,   8.48540474e-01,   6.05695903e-01],
                [  9.93865767e-01,   8.55711038e-01,   6.12481798e-01],
                [  9.93545285e-01,   8.62858846e-01,   6.19299300e-01],
                [  9.93169558e-01,   8.70024467e-01,   6.26189463e-01],
                [  9.92830963e-01,   8.77168404e-01,   6.33109148e-01],
                [  9.92439881e-01,   8.84329694e-01,   6.40099465e-01],
                [  9.92089454e-01,   8.91469549e-01,   6.47116021e-01],
                [  9.91687744e-01,   8.98627050e-01,   6.54201544e-01],
                [  9.91331929e-01,   9.05762748e-01,   6.61308839e-01],
                [  9.90929685e-01,   9.12915010e-01,   6.68481201e-01],
                [  9.90569914e-01,   9.20048699e-01,   6.75674592e-01],
                [  9.90174637e-01,   9.27195612e-01,   6.82925602e-01],
                [  9.89814839e-01,   9.34328540e-01,   6.90198194e-01],
                [  9.89433736e-01,   9.41470354e-01,   6.97518628e-01],
                [  9.89077438e-01,   9.48604077e-01,   7.04862519e-01],
                [  9.88717064e-01,   9.55741520e-01,   7.12242232e-01],
                [  9.88367028e-01,   9.62878026e-01,   7.19648627e-01],
                [  9.88032885e-01,   9.70012413e-01,   7.27076773e-01],
                [  9.87690702e-01,   9.77154231e-01,   7.34536205e-01],
                [  9.87386827e-01,   9.84287561e-01,   7.42001547e-01],
                [  9.87052509e-01,   9.91437853e-01,   7.49504188e-01]];
            if nargin < 1
                cm_data = cm;
            else
                hsv=rgb2hsv(cm);
                hsv(170:end,1)=hsv(170:end,1)+1; % hardcoded
                cm_data=interp1(linspace(0,1,size(cm,1)),hsv,linspace(0,1,m));
                cm_data(cm_data(:,1)>1,1)=cm_data(cm_data(:,1)>1,1)-1;
                cm_data=hsv2rgb(cm_data);

            end
        end%FCN:ColMapMagma

        function [cm_data]=ColMapPlasma(m)
            cm = [[  5.03832136e-02,   2.98028976e-02,   5.27974883e-01],
                [  6.35363639e-02,   2.84259729e-02,   5.33123681e-01],
                [  7.53531234e-02,   2.72063728e-02,   5.38007001e-01],
                [  8.62217979e-02,   2.61253206e-02,   5.42657691e-01],
                [  9.63786097e-02,   2.51650976e-02,   5.47103487e-01],
                [  1.05979704e-01,   2.43092436e-02,   5.51367851e-01],
                [  1.15123641e-01,   2.35562500e-02,   5.55467728e-01],
                [  1.23902903e-01,   2.28781011e-02,   5.59423480e-01],
                [  1.32380720e-01,   2.22583774e-02,   5.63250116e-01],
                [  1.40603076e-01,   2.16866674e-02,   5.66959485e-01],
                [  1.48606527e-01,   2.11535876e-02,   5.70561711e-01],
                [  1.56420649e-01,   2.06507174e-02,   5.74065446e-01],
                [  1.64069722e-01,   2.01705326e-02,   5.77478074e-01],
                [  1.71573925e-01,   1.97063415e-02,   5.80805890e-01],
                [  1.78950212e-01,   1.92522243e-02,   5.84054243e-01],
                [  1.86212958e-01,   1.88029767e-02,   5.87227661e-01],
                [  1.93374449e-01,   1.83540593e-02,   5.90329954e-01],
                [  2.00445260e-01,   1.79015512e-02,   5.93364304e-01],
                [  2.07434551e-01,   1.74421086e-02,   5.96333341e-01],
                [  2.14350298e-01,   1.69729276e-02,   5.99239207e-01],
                [  2.21196750e-01,   1.64970484e-02,   6.02083323e-01],
                [  2.27982971e-01,   1.60071509e-02,   6.04867403e-01],
                [  2.34714537e-01,   1.55015065e-02,   6.07592438e-01],
                [  2.41396253e-01,   1.49791041e-02,   6.10259089e-01],
                [  2.48032377e-01,   1.44393586e-02,   6.12867743e-01],
                [  2.54626690e-01,   1.38820918e-02,   6.15418537e-01],
                [  2.61182562e-01,   1.33075156e-02,   6.17911385e-01],
                [  2.67702993e-01,   1.27162163e-02,   6.20345997e-01],
                [  2.74190665e-01,   1.21091423e-02,   6.22721903e-01],
                [  2.80647969e-01,   1.14875915e-02,   6.25038468e-01],
                [  2.87076059e-01,   1.08554862e-02,   6.27294975e-01],
                [  2.93477695e-01,   1.02128849e-02,   6.29490490e-01],
                [  2.99855122e-01,   9.56079551e-03,   6.31623923e-01],
                [  3.06209825e-01,   8.90185346e-03,   6.33694102e-01],
                [  3.12543124e-01,   8.23900704e-03,   6.35699759e-01],
                [  3.18856183e-01,   7.57551051e-03,   6.37639537e-01],
                [  3.25150025e-01,   6.91491734e-03,   6.39512001e-01],
                [  3.31425547e-01,   6.26107379e-03,   6.41315649e-01],
                [  3.37683446e-01,   5.61830889e-03,   6.43048936e-01],
                [  3.43924591e-01,   4.99053080e-03,   6.44710195e-01],
                [  3.50149699e-01,   4.38202557e-03,   6.46297711e-01],
                [  3.56359209e-01,   3.79781761e-03,   6.47809772e-01],
                [  3.62553473e-01,   3.24319591e-03,   6.49244641e-01],
                [  3.68732762e-01,   2.72370721e-03,   6.50600561e-01],
                [  3.74897270e-01,   2.24514897e-03,   6.51875762e-01],
                [  3.81047116e-01,   1.81356205e-03,   6.53068467e-01],
                [  3.87182639e-01,   1.43446923e-03,   6.54176761e-01],
                [  3.93304010e-01,   1.11388259e-03,   6.55198755e-01],
                [  3.99410821e-01,   8.59420809e-04,   6.56132835e-01],
                [  4.05502914e-01,   6.78091517e-04,   6.56977276e-01],
                [  4.11580082e-01,   5.77101735e-04,   6.57730380e-01],
                [  4.17642063e-01,   5.63847476e-04,   6.58390492e-01],
                [  4.23688549e-01,   6.45902780e-04,   6.58956004e-01],
                [  4.29719186e-01,   8.31008207e-04,   6.59425363e-01],
                [  4.35733575e-01,   1.12705875e-03,   6.59797077e-01],
                [  4.41732123e-01,   1.53984779e-03,   6.60069009e-01],
                [  4.47713600e-01,   2.07954744e-03,   6.60240367e-01],
                [  4.53677394e-01,   2.75470302e-03,   6.60309966e-01],
                [  4.59622938e-01,   3.57374415e-03,   6.60276655e-01],
                [  4.65549631e-01,   4.54518084e-03,   6.60139383e-01],
                [  4.71456847e-01,   5.67758762e-03,   6.59897210e-01],
                [  4.77343929e-01,   6.97958743e-03,   6.59549311e-01],
                [  4.83210198e-01,   8.45983494e-03,   6.59094989e-01],
                [  4.89054951e-01,   1.01269996e-02,   6.58533677e-01],
                [  4.94877466e-01,   1.19897486e-02,   6.57864946e-01],
                [  5.00677687e-01,   1.40550640e-02,   6.57087561e-01],
                [  5.06454143e-01,   1.63333443e-02,   6.56202294e-01],
                [  5.12206035e-01,   1.88332232e-02,   6.55209222e-01],
                [  5.17932580e-01,   2.15631918e-02,   6.54108545e-01],
                [  5.23632990e-01,   2.45316468e-02,   6.52900629e-01],
                [  5.29306474e-01,   2.77468735e-02,   6.51586010e-01],
                [  5.34952244e-01,   3.12170300e-02,   6.50165396e-01],
                [  5.40569510e-01,   3.49501310e-02,   6.48639668e-01],
                [  5.46157494e-01,   3.89540334e-02,   6.47009884e-01],
                [  5.51715423e-01,   4.31364795e-02,   6.45277275e-01],
                [  5.57242538e-01,   4.73307585e-02,   6.43443250e-01],
                [  5.62738096e-01,   5.15448092e-02,   6.41509389e-01],
                [  5.68201372e-01,   5.57776706e-02,   6.39477440e-01],
                [  5.73631859e-01,   6.00281369e-02,   6.37348841e-01],
                [  5.79028682e-01,   6.42955547e-02,   6.35126108e-01],
                [  5.84391137e-01,   6.85790261e-02,   6.32811608e-01],
                [  5.89718606e-01,   7.28775875e-02,   6.30407727e-01],
                [  5.95010505e-01,   7.71902878e-02,   6.27916992e-01],
                [  6.00266283e-01,   8.15161895e-02,   6.25342058e-01],
                [  6.05485428e-01,   8.58543713e-02,   6.22685703e-01],
                [  6.10667469e-01,   9.02039303e-02,   6.19950811e-01],
                [  6.15811974e-01,   9.45639838e-02,   6.17140367e-01],
                [  6.20918555e-01,   9.89336721e-02,   6.14257440e-01],
                [  6.25986869e-01,   1.03312160e-01,   6.11305174e-01],
                [  6.31016615e-01,   1.07698641e-01,   6.08286774e-01],
                [  6.36007543e-01,   1.12092335e-01,   6.05205491e-01],
                [  6.40959444e-01,   1.16492495e-01,   6.02064611e-01],
                [  6.45872158e-01,   1.20898405e-01,   5.98867442e-01],
                [  6.50745571e-01,   1.25309384e-01,   5.95617300e-01],
                [  6.55579615e-01,   1.29724785e-01,   5.92317494e-01],
                [  6.60374266e-01,   1.34143997e-01,   5.88971318e-01],
                [  6.65129493e-01,   1.38566428e-01,   5.85582301e-01],
                [  6.69845385e-01,   1.42991540e-01,   5.82153572e-01],
                [  6.74522060e-01,   1.47418835e-01,   5.78688247e-01],
                [  6.79159664e-01,   1.51847851e-01,   5.75189431e-01],
                [  6.83758384e-01,   1.56278163e-01,   5.71660158e-01],
                [  6.88318440e-01,   1.60709387e-01,   5.68103380e-01],
                [  6.92840088e-01,   1.65141174e-01,   5.64521958e-01],
                [  6.97323615e-01,   1.69573215e-01,   5.60918659e-01],
                [  7.01769334e-01,   1.74005236e-01,   5.57296144e-01],
                [  7.06177590e-01,   1.78437000e-01,   5.53656970e-01],
                [  7.10548747e-01,   1.82868306e-01,   5.50003579e-01],
                [  7.14883195e-01,   1.87298986e-01,   5.46338299e-01],
                [  7.19181339e-01,   1.91728906e-01,   5.42663338e-01],
                [  7.23443604e-01,   1.96157962e-01,   5.38980786e-01],
                [  7.27670428e-01,   2.00586086e-01,   5.35292612e-01],
                [  7.31862231e-01,   2.05013174e-01,   5.31600995e-01],
                [  7.36019424e-01,   2.09439071e-01,   5.27908434e-01],
                [  7.40142557e-01,   2.13863965e-01,   5.24215533e-01],
                [  7.44232102e-01,   2.18287899e-01,   5.20523766e-01],
                [  7.48288533e-01,   2.22710942e-01,   5.16834495e-01],
                [  7.52312321e-01,   2.27133187e-01,   5.13148963e-01],
                [  7.56303937e-01,   2.31554749e-01,   5.09468305e-01],
                [  7.60263849e-01,   2.35975765e-01,   5.05793543e-01],
                [  7.64192516e-01,   2.40396394e-01,   5.02125599e-01],
                [  7.68090391e-01,   2.44816813e-01,   4.98465290e-01],
                [  7.71957916e-01,   2.49237220e-01,   4.94813338e-01],
                [  7.75795522e-01,   2.53657797e-01,   4.91170517e-01],
                [  7.79603614e-01,   2.58078397e-01,   4.87539124e-01],
                [  7.83382636e-01,   2.62499662e-01,   4.83917732e-01],
                [  7.87132978e-01,   2.66921859e-01,   4.80306702e-01],
                [  7.90855015e-01,   2.71345267e-01,   4.76706319e-01],
                [  7.94549101e-01,   2.75770179e-01,   4.73116798e-01],
                [  7.98215577e-01,   2.80196901e-01,   4.69538286e-01],
                [  8.01854758e-01,   2.84625750e-01,   4.65970871e-01],
                [  8.05466945e-01,   2.89057057e-01,   4.62414580e-01],
                [  8.09052419e-01,   2.93491117e-01,   4.58869577e-01],
                [  8.12611506e-01,   2.97927865e-01,   4.55337565e-01],
                [  8.16144382e-01,   3.02368130e-01,   4.51816385e-01],
                [  8.19651255e-01,   3.06812282e-01,   4.48305861e-01],
                [  8.23132309e-01,   3.11260703e-01,   4.44805781e-01],
                [  8.26587706e-01,   3.15713782e-01,   4.41315901e-01],
                [  8.30017584e-01,   3.20171913e-01,   4.37835947e-01],
                [  8.33422053e-01,   3.24635499e-01,   4.34365616e-01],
                [  8.36801237e-01,   3.29104836e-01,   4.30905052e-01],
                [  8.40155276e-01,   3.33580106e-01,   4.27454836e-01],
                [  8.43484103e-01,   3.38062109e-01,   4.24013059e-01],
                [  8.46787726e-01,   3.42551272e-01,   4.20579333e-01],
                [  8.50066132e-01,   3.47048028e-01,   4.17153264e-01],
                [  8.53319279e-01,   3.51552815e-01,   4.13734445e-01],
                [  8.56547103e-01,   3.56066072e-01,   4.10322469e-01],
                [  8.59749520e-01,   3.60588229e-01,   4.06916975e-01],
                [  8.62926559e-01,   3.65119408e-01,   4.03518809e-01],
                [  8.66077920e-01,   3.69660446e-01,   4.00126027e-01],
                [  8.69203436e-01,   3.74211795e-01,   3.96738211e-01],
                [  8.72302917e-01,   3.78773910e-01,   3.93354947e-01],
                [  8.75376149e-01,   3.83347243e-01,   3.89975832e-01],
                [  8.78422895e-01,   3.87932249e-01,   3.86600468e-01],
                [  8.81442916e-01,   3.92529339e-01,   3.83228622e-01],
                [  8.84435982e-01,   3.97138877e-01,   3.79860246e-01],
                [  8.87401682e-01,   4.01761511e-01,   3.76494232e-01],
                [  8.90339687e-01,   4.06397694e-01,   3.73130228e-01],
                [  8.93249647e-01,   4.11047871e-01,   3.69767893e-01],
                [  8.96131191e-01,   4.15712489e-01,   3.66406907e-01],
                [  8.98983931e-01,   4.20391986e-01,   3.63046965e-01],
                [  9.01807455e-01,   4.25086807e-01,   3.59687758e-01],
                [  9.04601295e-01,   4.29797442e-01,   3.56328796e-01],
                [  9.07364995e-01,   4.34524335e-01,   3.52969777e-01],
                [  9.10098088e-01,   4.39267908e-01,   3.49610469e-01],
                [  9.12800095e-01,   4.44028574e-01,   3.46250656e-01],
                [  9.15470518e-01,   4.48806744e-01,   3.42890148e-01],
                [  9.18108848e-01,   4.53602818e-01,   3.39528771e-01],
                [  9.20714383e-01,   4.58417420e-01,   3.36165582e-01],
                [  9.23286660e-01,   4.63250828e-01,   3.32800827e-01],
                [  9.25825146e-01,   4.68103387e-01,   3.29434512e-01],
                [  9.28329275e-01,   4.72975465e-01,   3.26066550e-01],
                [  9.30798469e-01,   4.77867420e-01,   3.22696876e-01],
                [  9.33232140e-01,   4.82779603e-01,   3.19325444e-01],
                [  9.35629684e-01,   4.87712357e-01,   3.15952211e-01],
                [  9.37990034e-01,   4.92666544e-01,   3.12575440e-01],
                [  9.40312939e-01,   4.97642038e-01,   3.09196628e-01],
                [  9.42597771e-01,   5.02639147e-01,   3.05815824e-01],
                [  9.44843893e-01,   5.07658169e-01,   3.02433101e-01],
                [  9.47050662e-01,   5.12699390e-01,   2.99048555e-01],
                [  9.49217427e-01,   5.17763087e-01,   2.95662308e-01],
                [  9.51343530e-01,   5.22849522e-01,   2.92274506e-01],
                [  9.53427725e-01,   5.27959550e-01,   2.88883445e-01],
                [  9.55469640e-01,   5.33093083e-01,   2.85490391e-01],
                [  9.57468770e-01,   5.38250172e-01,   2.82096149e-01],
                [  9.59424430e-01,   5.43431038e-01,   2.78700990e-01],
                [  9.61335930e-01,   5.48635890e-01,   2.75305214e-01],
                [  9.63202573e-01,   5.53864931e-01,   2.71909159e-01],
                [  9.65023656e-01,   5.59118349e-01,   2.68513200e-01],
                [  9.66798470e-01,   5.64396327e-01,   2.65117752e-01],
                [  9.68525639e-01,   5.69699633e-01,   2.61721488e-01],
                [  9.70204593e-01,   5.75028270e-01,   2.58325424e-01],
                [  9.71835007e-01,   5.80382015e-01,   2.54931256e-01],
                [  9.73416145e-01,   5.85761012e-01,   2.51539615e-01],
                [  9.74947262e-01,   5.91165394e-01,   2.48151200e-01],
                [  9.76427606e-01,   5.96595287e-01,   2.44766775e-01],
                [  9.77856416e-01,   6.02050811e-01,   2.41387186e-01],
                [  9.79232922e-01,   6.07532077e-01,   2.38013359e-01],
                [  9.80556344e-01,   6.13039190e-01,   2.34646316e-01],
                [  9.81825890e-01,   6.18572250e-01,   2.31287178e-01],
                [  9.83040742e-01,   6.24131362e-01,   2.27937141e-01],
                [  9.84198924e-01,   6.29717516e-01,   2.24595006e-01],
                [  9.85300760e-01,   6.35329876e-01,   2.21264889e-01],
                [  9.86345421e-01,   6.40968508e-01,   2.17948456e-01],
                [  9.87332067e-01,   6.46633475e-01,   2.14647532e-01],
                [  9.88259846e-01,   6.52324832e-01,   2.11364122e-01],
                [  9.89127893e-01,   6.58042630e-01,   2.08100426e-01],
                [  9.89935328e-01,   6.63786914e-01,   2.04858855e-01],
                [  9.90681261e-01,   6.69557720e-01,   2.01642049e-01],
                [  9.91364787e-01,   6.75355082e-01,   1.98452900e-01],
                [  9.91984990e-01,   6.81179025e-01,   1.95294567e-01],
                [  9.92540939e-01,   6.87029567e-01,   1.92170500e-01],
                [  9.93031693e-01,   6.92906719e-01,   1.89084459e-01],
                [  9.93456302e-01,   6.98810484e-01,   1.86040537e-01],
                [  9.93813802e-01,   7.04740854e-01,   1.83043180e-01],
                [  9.94103226e-01,   7.10697814e-01,   1.80097207e-01],
                [  9.94323596e-01,   7.16681336e-01,   1.77207826e-01],
                [  9.94473934e-01,   7.22691379e-01,   1.74380656e-01],
                [  9.94553260e-01,   7.28727890e-01,   1.71621733e-01],
                [  9.94560594e-01,   7.34790799e-01,   1.68937522e-01],
                [  9.94494964e-01,   7.40880020e-01,   1.66334918e-01],
                [  9.94355411e-01,   7.46995448e-01,   1.63821243e-01],
                [  9.94140989e-01,   7.53136955e-01,   1.61404226e-01],
                [  9.93850778e-01,   7.59304390e-01,   1.59091984e-01],
                [  9.93482190e-01,   7.65498551e-01,   1.56890625e-01],
                [  9.93033251e-01,   7.71719833e-01,   1.54807583e-01],
                [  9.92505214e-01,   7.77966775e-01,   1.52854862e-01],
                [  9.91897270e-01,   7.84239120e-01,   1.51041581e-01],
                [  9.91208680e-01,   7.90536569e-01,   1.49376885e-01],
                [  9.90438793e-01,   7.96858775e-01,   1.47869810e-01],
                [  9.89587065e-01,   8.03205337e-01,   1.46529128e-01],
                [  9.88647741e-01,   8.09578605e-01,   1.45357284e-01],
                [  9.87620557e-01,   8.15977942e-01,   1.44362644e-01],
                [  9.86509366e-01,   8.22400620e-01,   1.43556679e-01],
                [  9.85314198e-01,   8.28845980e-01,   1.42945116e-01],
                [  9.84031139e-01,   8.35315360e-01,   1.42528388e-01],
                [  9.82652820e-01,   8.41811730e-01,   1.42302653e-01],
                [  9.81190389e-01,   8.48328902e-01,   1.42278607e-01],
                [  9.79643637e-01,   8.54866468e-01,   1.42453425e-01],
                [  9.77994918e-01,   8.61432314e-01,   1.42808191e-01],
                [  9.76264977e-01,   8.68015998e-01,   1.43350944e-01],
                [  9.74443038e-01,   8.74622194e-01,   1.44061156e-01],
                [  9.72530009e-01,   8.81250063e-01,   1.44922913e-01],
                [  9.70532932e-01,   8.87896125e-01,   1.45918663e-01],
                [  9.68443477e-01,   8.94563989e-01,   1.47014438e-01],
                [  9.66271225e-01,   9.01249365e-01,   1.48179639e-01],
                [  9.64021057e-01,   9.07950379e-01,   1.49370428e-01],
                [  9.61681481e-01,   9.14672479e-01,   1.50520343e-01],
                [  9.59275646e-01,   9.21406537e-01,   1.51566019e-01],
                [  9.56808068e-01,   9.28152065e-01,   1.52409489e-01],
                [  9.54286813e-01,   9.34907730e-01,   1.52921158e-01],
                [  9.51726083e-01,   9.41670605e-01,   1.52925363e-01],
                [  9.49150533e-01,   9.48434900e-01,   1.52177604e-01],
                [  9.46602270e-01,   9.55189860e-01,   1.50327944e-01],
                [  9.44151742e-01,   9.61916487e-01,   1.46860789e-01],
                [  9.41896120e-01,   9.68589814e-01,   1.40955606e-01],
                [  9.40015097e-01,   9.75158357e-01,   1.31325517e-01]];

            if nargin < 1
                cm_data = cm;
            else
                hsv=rgb2hsv(cm);
                hsv(153:end,1)=hsv(153:end,1)+1; % hardcoded
                cm_data=interp1(linspace(0,1,size(cm,1)),hsv,linspace(0,1,m));
                cm_data(cm_data(:,1)>1,1)=cm_data(cm_data(:,1)>1,1)-1;
                cm_data=hsv2rgb(cm_data);

            end
        end%FCN:ColMapPlasma

        function [cm_data]=ColMapInferno(m)
            cm = [[  1.46159096e-03,   4.66127766e-04,   1.38655200e-02],
                [  2.26726368e-03,   1.26992553e-03,   1.85703520e-02],
                [  3.29899092e-03,   2.24934863e-03,   2.42390508e-02],
                [  4.54690615e-03,   3.39180156e-03,   3.09092475e-02],
                [  6.00552565e-03,   4.69194561e-03,   3.85578980e-02],
                [  7.67578856e-03,   6.13611626e-03,   4.68360336e-02],
                [  9.56051094e-03,   7.71344131e-03,   5.51430756e-02],
                [  1.16634769e-02,   9.41675403e-03,   6.34598080e-02],
                [  1.39950388e-02,   1.12247138e-02,   7.18616890e-02],
                [  1.65605595e-02,   1.31362262e-02,   8.02817951e-02],
                [  1.93732295e-02,   1.51325789e-02,   8.87668094e-02],
                [  2.24468865e-02,   1.71991484e-02,   9.73274383e-02],
                [  2.57927373e-02,   1.93306298e-02,   1.05929835e-01],
                [  2.94324251e-02,   2.15030771e-02,   1.14621328e-01],
                [  3.33852235e-02,   2.37024271e-02,   1.23397286e-01],
                [  3.76684211e-02,   2.59207864e-02,   1.32232108e-01],
                [  4.22525554e-02,   2.81385015e-02,   1.41140519e-01],
                [  4.69146287e-02,   3.03236129e-02,   1.50163867e-01],
                [  5.16437624e-02,   3.24736172e-02,   1.59254277e-01],
                [  5.64491009e-02,   3.45691867e-02,   1.68413539e-01],
                [  6.13397200e-02,   3.65900213e-02,   1.77642172e-01],
                [  6.63312620e-02,   3.85036268e-02,   1.86961588e-01],
                [  7.14289181e-02,   4.02939095e-02,   1.96353558e-01],
                [  7.66367560e-02,   4.19053329e-02,   2.05798788e-01],
                [  8.19620773e-02,   4.33278666e-02,   2.15289113e-01],
                [  8.74113897e-02,   4.45561662e-02,   2.24813479e-01],
                [  9.29901526e-02,   4.55829503e-02,   2.34357604e-01],
                [  9.87024972e-02,   4.64018731e-02,   2.43903700e-01],
                [  1.04550936e-01,   4.70080541e-02,   2.53430300e-01],
                [  1.10536084e-01,   4.73986708e-02,   2.62912235e-01],
                [  1.16656423e-01,   4.75735920e-02,   2.72320803e-01],
                [  1.22908126e-01,   4.75360183e-02,   2.81624170e-01],
                [  1.29284984e-01,   4.72930838e-02,   2.90788012e-01],
                [  1.35778450e-01,   4.68563678e-02,   2.99776404e-01],
                [  1.42377819e-01,   4.62422566e-02,   3.08552910e-01],
                [  1.49072957e-01,   4.54676444e-02,   3.17085139e-01],
                [  1.55849711e-01,   4.45588056e-02,   3.25338414e-01],
                [  1.62688939e-01,   4.35542881e-02,   3.33276678e-01],
                [  1.69575148e-01,   4.24893149e-02,   3.40874188e-01],
                [  1.76493202e-01,   4.14017089e-02,   3.48110606e-01],
                [  1.83428775e-01,   4.03288858e-02,   3.54971391e-01],
                [  1.90367453e-01,   3.93088888e-02,   3.61446945e-01],
                [  1.97297425e-01,   3.84001825e-02,   3.67534629e-01],
                [  2.04209298e-01,   3.76322609e-02,   3.73237557e-01],
                [  2.11095463e-01,   3.70296488e-02,   3.78563264e-01],
                [  2.17948648e-01,   3.66146049e-02,   3.83522415e-01],
                [  2.24762908e-01,   3.64049901e-02,   3.88128944e-01],
                [  2.31538148e-01,   3.64052511e-02,   3.92400150e-01],
                [  2.38272961e-01,   3.66209949e-02,   3.96353388e-01],
                [  2.44966911e-01,   3.70545017e-02,   4.00006615e-01],
                [  2.51620354e-01,   3.77052832e-02,   4.03377897e-01],
                [  2.58234265e-01,   3.85706153e-02,   4.06485031e-01],
                [  2.64809649e-01,   3.96468666e-02,   4.09345373e-01],
                [  2.71346664e-01,   4.09215821e-02,   4.11976086e-01],
                [  2.77849829e-01,   4.23528741e-02,   4.14392106e-01],
                [  2.84321318e-01,   4.39325787e-02,   4.16607861e-01],
                [  2.90763373e-01,   4.56437598e-02,   4.18636756e-01],
                [  2.97178251e-01,   4.74700293e-02,   4.20491164e-01],
                [  3.03568182e-01,   4.93958927e-02,   4.22182449e-01],
                [  3.09935342e-01,   5.14069729e-02,   4.23720999e-01],
                [  3.16281835e-01,   5.34901321e-02,   4.25116277e-01],
                [  3.22609671e-01,   5.56335178e-02,   4.26376869e-01],
                [  3.28920763e-01,   5.78265505e-02,   4.27510546e-01],
                [  3.35216916e-01,   6.00598734e-02,   4.28524320e-01],
                [  3.41499828e-01,   6.23252772e-02,   4.29424503e-01],
                [  3.47771086e-01,   6.46156100e-02,   4.30216765e-01],
                [  3.54032169e-01,   6.69246832e-02,   4.30906186e-01],
                [  3.60284449e-01,   6.92471753e-02,   4.31497309e-01],
                [  3.66529195e-01,   7.15785403e-02,   4.31994185e-01],
                [  3.72767575e-01,   7.39149211e-02,   4.32400419e-01],
                [  3.79000659e-01,   7.62530701e-02,   4.32719214e-01],
                [  3.85228383e-01,   7.85914864e-02,   4.32954973e-01],
                [  3.91452659e-01,   8.09267058e-02,   4.33108763e-01],
                [  3.97674379e-01,   8.32568129e-02,   4.33182647e-01],
                [  4.03894278e-01,   8.55803445e-02,   4.33178526e-01],
                [  4.10113015e-01,   8.78961593e-02,   4.33098056e-01],
                [  4.16331169e-01,   9.02033992e-02,   4.32942678e-01],
                [  4.22549249e-01,   9.25014543e-02,   4.32713635e-01],
                [  4.28767696e-01,   9.47899342e-02,   4.32411996e-01],
                [  4.34986885e-01,   9.70686417e-02,   4.32038673e-01],
                [  4.41207124e-01,   9.93375510e-02,   4.31594438e-01],
                [  4.47428382e-01,   1.01597079e-01,   4.31080497e-01],
                [  4.53650614e-01,   1.03847716e-01,   4.30497898e-01],
                [  4.59874623e-01,   1.06089165e-01,   4.29845789e-01],
                [  4.66100494e-01,   1.08321923e-01,   4.29124507e-01],
                [  4.72328255e-01,   1.10546584e-01,   4.28334320e-01],
                [  4.78557889e-01,   1.12763831e-01,   4.27475431e-01],
                [  4.84789325e-01,   1.14974430e-01,   4.26547991e-01],
                [  4.91022448e-01,   1.17179219e-01,   4.25552106e-01],
                [  4.97257069e-01,   1.19379132e-01,   4.24487908e-01],
                [  5.03492698e-01,   1.21575414e-01,   4.23356110e-01],
                [  5.09729541e-01,   1.23768654e-01,   4.22155676e-01],
                [  5.15967304e-01,   1.25959947e-01,   4.20886594e-01],
                [  5.22205646e-01,   1.28150439e-01,   4.19548848e-01],
                [  5.28444192e-01,   1.30341324e-01,   4.18142411e-01],
                [  5.34682523e-01,   1.32533845e-01,   4.16667258e-01],
                [  5.40920186e-01,   1.34729286e-01,   4.15123366e-01],
                [  5.47156706e-01,   1.36928959e-01,   4.13510662e-01],
                [  5.53391649e-01,   1.39134147e-01,   4.11828882e-01],
                [  5.59624442e-01,   1.41346265e-01,   4.10078028e-01],
                [  5.65854477e-01,   1.43566769e-01,   4.08258132e-01],
                [  5.72081108e-01,   1.45797150e-01,   4.06369246e-01],
                [  5.78303656e-01,   1.48038934e-01,   4.04411444e-01],
                [  5.84521407e-01,   1.50293679e-01,   4.02384829e-01],
                [  5.90733615e-01,   1.52562977e-01,   4.00289528e-01],
                [  5.96939751e-01,   1.54848232e-01,   3.98124897e-01],
                [  6.03138930e-01,   1.57151161e-01,   3.95891308e-01],
                [  6.09330184e-01,   1.59473549e-01,   3.93589349e-01],
                [  6.15512627e-01,   1.61817111e-01,   3.91219295e-01],
                [  6.21685340e-01,   1.64183582e-01,   3.88781456e-01],
                [  6.27847374e-01,   1.66574724e-01,   3.86276180e-01],
                [  6.33997746e-01,   1.68992314e-01,   3.83703854e-01],
                [  6.40135447e-01,   1.71438150e-01,   3.81064906e-01],
                [  6.46259648e-01,   1.73913876e-01,   3.78358969e-01],
                [  6.52369348e-01,   1.76421271e-01,   3.75586209e-01],
                [  6.58463166e-01,   1.78962399e-01,   3.72748214e-01],
                [  6.64539964e-01,   1.81539111e-01,   3.69845599e-01],
                [  6.70598572e-01,   1.84153268e-01,   3.66879025e-01],
                [  6.76637795e-01,   1.86806728e-01,   3.63849195e-01],
                [  6.82656407e-01,   1.89501352e-01,   3.60756856e-01],
                [  6.88653158e-01,   1.92238994e-01,   3.57602797e-01],
                [  6.94626769e-01,   1.95021500e-01,   3.54387853e-01],
                [  7.00575937e-01,   1.97850703e-01,   3.51112900e-01],
                [  7.06499709e-01,   2.00728196e-01,   3.47776863e-01],
                [  7.12396345e-01,   2.03656029e-01,   3.44382594e-01],
                [  7.18264447e-01,   2.06635993e-01,   3.40931208e-01],
                [  7.24102613e-01,   2.09669834e-01,   3.37423766e-01],
                [  7.29909422e-01,   2.12759270e-01,   3.33861367e-01],
                [  7.35683432e-01,   2.15905976e-01,   3.30245147e-01],
                [  7.41423185e-01,   2.19111589e-01,   3.26576275e-01],
                [  7.47127207e-01,   2.22377697e-01,   3.22855952e-01],
                [  7.52794009e-01,   2.25705837e-01,   3.19085410e-01],
                [  7.58422090e-01,   2.29097492e-01,   3.15265910e-01],
                [  7.64009940e-01,   2.32554083e-01,   3.11398734e-01],
                [  7.69556038e-01,   2.36076967e-01,   3.07485188e-01],
                [  7.75058888e-01,   2.39667435e-01,   3.03526312e-01],
                [  7.80517023e-01,   2.43326720e-01,   2.99522665e-01],
                [  7.85928794e-01,   2.47055968e-01,   2.95476756e-01],
                [  7.91292674e-01,   2.50856232e-01,   2.91389943e-01],
                [  7.96607144e-01,   2.54728485e-01,   2.87263585e-01],
                [  8.01870689e-01,   2.58673610e-01,   2.83099033e-01],
                [  8.07081807e-01,   2.62692401e-01,   2.78897629e-01],
                [  8.12239008e-01,   2.66785558e-01,   2.74660698e-01],
                [  8.17340818e-01,   2.70953688e-01,   2.70389545e-01],
                [  8.22385784e-01,   2.75197300e-01,   2.66085445e-01],
                [  8.27372474e-01,   2.79516805e-01,   2.61749643e-01],
                [  8.32299481e-01,   2.83912516e-01,   2.57383341e-01],
                [  8.37165425e-01,   2.88384647e-01,   2.52987700e-01],
                [  8.41968959e-01,   2.92933312e-01,   2.48563825e-01],
                [  8.46708768e-01,   2.97558528e-01,   2.44112767e-01],
                [  8.51383572e-01,   3.02260213e-01,   2.39635512e-01],
                [  8.55992130e-01,   3.07038188e-01,   2.35132978e-01],
                [  8.60533241e-01,   3.11892183e-01,   2.30606009e-01],
                [  8.65005747e-01,   3.16821833e-01,   2.26055368e-01],
                [  8.69408534e-01,   3.21826685e-01,   2.21481734e-01],
                [  8.73740530e-01,   3.26906201e-01,   2.16885699e-01],
                [  8.78000715e-01,   3.32059760e-01,   2.12267762e-01],
                [  8.82188112e-01,   3.37286663e-01,   2.07628326e-01],
                [  8.86301795e-01,   3.42586137e-01,   2.02967696e-01],
                [  8.90340885e-01,   3.47957340e-01,   1.98286080e-01],
                [  8.94304553e-01,   3.53399363e-01,   1.93583583e-01],
                [  8.98192017e-01,   3.58911240e-01,   1.88860212e-01],
                [  9.02002544e-01,   3.64491949e-01,   1.84115876e-01],
                [  9.05735448e-01,   3.70140419e-01,   1.79350388e-01],
                [  9.09390090e-01,   3.75855533e-01,   1.74563472e-01],
                [  9.12965874e-01,   3.81636138e-01,   1.69754764e-01],
                [  9.16462251e-01,   3.87481044e-01,   1.64923826e-01],
                [  9.19878710e-01,   3.93389034e-01,   1.60070152e-01],
                [  9.23214783e-01,   3.99358867e-01,   1.55193185e-01],
                [  9.26470039e-01,   4.05389282e-01,   1.50292329e-01],
                [  9.29644083e-01,   4.11479007e-01,   1.45366973e-01],
                [  9.32736555e-01,   4.17626756e-01,   1.40416519e-01],
                [  9.35747126e-01,   4.23831237e-01,   1.35440416e-01],
                [  9.38675494e-01,   4.30091162e-01,   1.30438175e-01],
                [  9.41521384e-01,   4.36405243e-01,   1.25409440e-01],
                [  9.44284543e-01,   4.42772199e-01,   1.20354038e-01],
                [  9.46964741e-01,   4.49190757e-01,   1.15272059e-01],
                [  9.49561766e-01,   4.55659658e-01,   1.10163947e-01],
                [  9.52075421e-01,   4.62177656e-01,   1.05030614e-01],
                [  9.54505523e-01,   4.68743522e-01,   9.98735931e-02],
                [  9.56851903e-01,   4.75356048e-01,   9.46952268e-02],
                [  9.59114397e-01,   4.82014044e-01,   8.94989073e-02],
                [  9.61292850e-01,   4.88716345e-01,   8.42893891e-02],
                [  9.63387110e-01,   4.95461806e-01,   7.90731907e-02],
                [  9.65397031e-01,   5.02249309e-01,   7.38591143e-02],
                [  9.67322465e-01,   5.09077761e-01,   6.86589199e-02],
                [  9.69163264e-01,   5.15946092e-01,   6.34881971e-02],
                [  9.70919277e-01,   5.22853259e-01,   5.83674890e-02],
                [  9.72590351e-01,   5.29798246e-01,   5.33237243e-02],
                [  9.74176327e-01,   5.36780059e-01,   4.83920090e-02],
                [  9.75677038e-01,   5.43797733e-01,   4.36177922e-02],
                [  9.77092313e-01,   5.50850323e-01,   3.90500131e-02],
                [  9.78421971e-01,   5.57936911e-01,   3.49306227e-02],
                [  9.79665824e-01,   5.65056600e-01,   3.14091591e-02],
                [  9.80823673e-01,   5.72208516e-01,   2.85075931e-02],
                [  9.81895311e-01,   5.79391803e-01,   2.62497353e-02],
                [  9.82880522e-01,   5.86605627e-01,   2.46613416e-02],
                [  9.83779081e-01,   5.93849168e-01,   2.37702263e-02],
                [  9.84590755e-01,   6.01121626e-01,   2.36063833e-02],
                [  9.85315301e-01,   6.08422211e-01,   2.42021174e-02],
                [  9.85952471e-01,   6.15750147e-01,   2.55921853e-02],
                [  9.86502013e-01,   6.23104667e-01,   2.78139496e-02],
                [  9.86963670e-01,   6.30485011e-01,   3.09075459e-02],
                [  9.87337182e-01,   6.37890424e-01,   3.49160639e-02],
                [  9.87622296e-01,   6.45320152e-01,   3.98857472e-02],
                [  9.87818759e-01,   6.52773439e-01,   4.55808037e-02],
                [  9.87926330e-01,   6.60249526e-01,   5.17503867e-02],
                [  9.87944783e-01,   6.67747641e-01,   5.83286889e-02],
                [  9.87873910e-01,   6.75267000e-01,   6.52570167e-02],
                [  9.87713535e-01,   6.82806802e-01,   7.24892330e-02],
                [  9.87463516e-01,   6.90366218e-01,   7.99897176e-02],
                [  9.87123759e-01,   6.97944391e-01,   8.77314215e-02],
                [  9.86694229e-01,   7.05540424e-01,   9.56941797e-02],
                [  9.86174970e-01,   7.13153375e-01,   1.03863324e-01],
                [  9.85565739e-01,   7.20782460e-01,   1.12228756e-01],
                [  9.84865203e-01,   7.28427497e-01,   1.20784651e-01],
                [  9.84075129e-01,   7.36086521e-01,   1.29526579e-01],
                [  9.83195992e-01,   7.43758326e-01,   1.38453063e-01],
                [  9.82228463e-01,   7.51441596e-01,   1.47564573e-01],
                [  9.81173457e-01,   7.59134892e-01,   1.56863224e-01],
                [  9.80032178e-01,   7.66836624e-01,   1.66352544e-01],
                [  9.78806183e-01,   7.74545028e-01,   1.76037298e-01],
                [  9.77497453e-01,   7.82258138e-01,   1.85923357e-01],
                [  9.76108474e-01,   7.89973753e-01,   1.96017589e-01],
                [  9.74637842e-01,   7.97691563e-01,   2.06331925e-01],
                [  9.73087939e-01,   8.05409333e-01,   2.16876839e-01],
                [  9.71467822e-01,   8.13121725e-01,   2.27658046e-01],
                [  9.69783146e-01,   8.20825143e-01,   2.38685942e-01],
                [  9.68040817e-01,   8.28515491e-01,   2.49971582e-01],
                [  9.66242589e-01,   8.36190976e-01,   2.61533898e-01],
                [  9.64393924e-01,   8.43848069e-01,   2.73391112e-01],
                [  9.62516656e-01,   8.51476340e-01,   2.85545675e-01],
                [  9.60625545e-01,   8.59068716e-01,   2.98010219e-01],
                [  9.58720088e-01,   8.66624355e-01,   3.10820466e-01],
                [  9.56834075e-01,   8.74128569e-01,   3.23973947e-01],
                [  9.54997177e-01,   8.81568926e-01,   3.37475479e-01],
                [  9.53215092e-01,   8.88942277e-01,   3.51368713e-01],
                [  9.51546225e-01,   8.96225909e-01,   3.65627005e-01],
                [  9.50018481e-01,   9.03409063e-01,   3.80271225e-01],
                [  9.48683391e-01,   9.10472964e-01,   3.95289169e-01],
                [  9.47594362e-01,   9.17399053e-01,   4.10665194e-01],
                [  9.46809163e-01,   9.24168246e-01,   4.26373236e-01],
                [  9.46391536e-01,   9.30760752e-01,   4.42367495e-01],
                [  9.46402951e-01,   9.37158971e-01,   4.58591507e-01],
                [  9.46902568e-01,   9.43347775e-01,   4.74969778e-01],
                [  9.47936825e-01,   9.49317522e-01,   4.91426053e-01],
                [  9.49544830e-01,   9.55062900e-01,   5.07859649e-01],
                [  9.51740304e-01,   9.60586693e-01,   5.24203026e-01],
                [  9.54529281e-01,   9.65895868e-01,   5.40360752e-01],
                [  9.57896053e-01,   9.71003330e-01,   5.56275090e-01],
                [  9.61812020e-01,   9.75924241e-01,   5.71925382e-01],
                [  9.66248822e-01,   9.80678193e-01,   5.87205773e-01],
                [  9.71161622e-01,   9.85282161e-01,   6.02154330e-01],
                [  9.76510983e-01,   9.89753437e-01,   6.16760413e-01],
                [  9.82257307e-01,   9.94108844e-01,   6.31017009e-01],
                [  9.88362068e-01,   9.98364143e-01,   6.44924005e-01]];
            if nargin < 1
                cm_data = cm;
            else
                hsv=rgb2hsv(cm);
                hsv(144:end,1)=hsv(144:end,1)+1; % hardcoded
                cm_data=interp1(linspace(0,1,size(cm,1)),hsv,linspace(0,1,m));
                cm_data(cm_data(:,1)>1,1)=cm_data(cm_data(:,1)>1,1)-1;
                cm_data=hsv2rgb(cm_data);

            end
        end%FCN:ColMapInferno

        function cm_data=ColMapViridis(m)
            cm = [[ 0.26700401,  0.00487433,  0.32941519],
                [ 0.26851048,  0.00960483,  0.33542652],
                [ 0.26994384,  0.01462494,  0.34137895],
                [ 0.27130489,  0.01994186,  0.34726862],
                [ 0.27259384,  0.02556309,  0.35309303],
                [ 0.27380934,  0.03149748,  0.35885256],
                [ 0.27495242,  0.03775181,  0.36454323],
                [ 0.27602238,  0.04416723,  0.37016418],
                [ 0.2770184 ,  0.05034437,  0.37571452],
                [ 0.27794143,  0.05632444,  0.38119074],
                [ 0.27879067,  0.06214536,  0.38659204],
                [ 0.2795655 ,  0.06783587,  0.39191723],
                [ 0.28026658,  0.07341724,  0.39716349],
                [ 0.28089358,  0.07890703,  0.40232944],
                [ 0.28144581,  0.0843197 ,  0.40741404],
                [ 0.28192358,  0.08966622,  0.41241521],
                [ 0.28232739,  0.09495545,  0.41733086],
                [ 0.28265633,  0.10019576,  0.42216032],
                [ 0.28291049,  0.10539345,  0.42690202],
                [ 0.28309095,  0.11055307,  0.43155375],
                [ 0.28319704,  0.11567966,  0.43611482],
                [ 0.28322882,  0.12077701,  0.44058404],
                [ 0.28318684,  0.12584799,  0.44496   ],
                [ 0.283072  ,  0.13089477,  0.44924127],
                [ 0.28288389,  0.13592005,  0.45342734],
                [ 0.28262297,  0.14092556,  0.45751726],
                [ 0.28229037,  0.14591233,  0.46150995],
                [ 0.28188676,  0.15088147,  0.46540474],
                [ 0.28141228,  0.15583425,  0.46920128],
                [ 0.28086773,  0.16077132,  0.47289909],
                [ 0.28025468,  0.16569272,  0.47649762],
                [ 0.27957399,  0.17059884,  0.47999675],
                [ 0.27882618,  0.1754902 ,  0.48339654],
                [ 0.27801236,  0.18036684,  0.48669702],
                [ 0.27713437,  0.18522836,  0.48989831],
                [ 0.27619376,  0.19007447,  0.49300074],
                [ 0.27519116,  0.1949054 ,  0.49600488],
                [ 0.27412802,  0.19972086,  0.49891131],
                [ 0.27300596,  0.20452049,  0.50172076],
                [ 0.27182812,  0.20930306,  0.50443413],
                [ 0.27059473,  0.21406899,  0.50705243],
                [ 0.26930756,  0.21881782,  0.50957678],
                [ 0.26796846,  0.22354911,  0.5120084 ],
                [ 0.26657984,  0.2282621 ,  0.5143487 ],
                [ 0.2651445 ,  0.23295593,  0.5165993 ],
                [ 0.2636632 ,  0.23763078,  0.51876163],
                [ 0.26213801,  0.24228619,  0.52083736],
                [ 0.26057103,  0.2469217 ,  0.52282822],
                [ 0.25896451,  0.25153685,  0.52473609],
                [ 0.25732244,  0.2561304 ,  0.52656332],
                [ 0.25564519,  0.26070284,  0.52831152],
                [ 0.25393498,  0.26525384,  0.52998273],
                [ 0.25219404,  0.26978306,  0.53157905],
                [ 0.25042462,  0.27429024,  0.53310261],
                [ 0.24862899,  0.27877509,  0.53455561],
                [ 0.2468114 ,  0.28323662,  0.53594093],
                [ 0.24497208,  0.28767547,  0.53726018],
                [ 0.24311324,  0.29209154,  0.53851561],
                [ 0.24123708,  0.29648471,  0.53970946],
                [ 0.23934575,  0.30085494,  0.54084398],
                [ 0.23744138,  0.30520222,  0.5419214 ],
                [ 0.23552606,  0.30952657,  0.54294396],
                [ 0.23360277,  0.31382773,  0.54391424],
                [ 0.2316735 ,  0.3181058 ,  0.54483444],
                [ 0.22973926,  0.32236127,  0.54570633],
                [ 0.22780192,  0.32659432,  0.546532  ],
                [ 0.2258633 ,  0.33080515,  0.54731353],
                [ 0.22392515,  0.334994  ,  0.54805291],
                [ 0.22198915,  0.33916114,  0.54875211],
                [ 0.22005691,  0.34330688,  0.54941304],
                [ 0.21812995,  0.34743154,  0.55003755],
                [ 0.21620971,  0.35153548,  0.55062743],
                [ 0.21429757,  0.35561907,  0.5511844 ],
                [ 0.21239477,  0.35968273,  0.55171011],
                [ 0.2105031 ,  0.36372671,  0.55220646],
                [ 0.20862342,  0.36775151,  0.55267486],
                [ 0.20675628,  0.37175775,  0.55311653],
                [ 0.20490257,  0.37574589,  0.55353282],
                [ 0.20306309,  0.37971644,  0.55392505],
                [ 0.20123854,  0.38366989,  0.55429441],
                [ 0.1994295 ,  0.38760678,  0.55464205],
                [ 0.1976365 ,  0.39152762,  0.55496905],
                [ 0.19585993,  0.39543297,  0.55527637],
                [ 0.19410009,  0.39932336,  0.55556494],
                [ 0.19235719,  0.40319934,  0.55583559],
                [ 0.19063135,  0.40706148,  0.55608907],
                [ 0.18892259,  0.41091033,  0.55632606],
                [ 0.18723083,  0.41474645,  0.55654717],
                [ 0.18555593,  0.4185704 ,  0.55675292],
                [ 0.18389763,  0.42238275,  0.55694377],
                [ 0.18225561,  0.42618405,  0.5571201 ],
                [ 0.18062949,  0.42997486,  0.55728221],
                [ 0.17901879,  0.43375572,  0.55743035],
                [ 0.17742298,  0.4375272 ,  0.55756466],
                [ 0.17584148,  0.44128981,  0.55768526],
                [ 0.17427363,  0.4450441 ,  0.55779216],
                [ 0.17271876,  0.4487906 ,  0.55788532],
                [ 0.17117615,  0.4525298 ,  0.55796464],
                [ 0.16964573,  0.45626209,  0.55803034],
                [ 0.16812641,  0.45998802,  0.55808199],
                [ 0.1666171 ,  0.46370813,  0.55811913],
                [ 0.16511703,  0.4674229 ,  0.55814141],
                [ 0.16362543,  0.47113278,  0.55814842],
                [ 0.16214155,  0.47483821,  0.55813967],
                [ 0.16066467,  0.47853961,  0.55811466],
                [ 0.15919413,  0.4822374 ,  0.5580728 ],
                [ 0.15772933,  0.48593197,  0.55801347],
                [ 0.15626973,  0.4896237 ,  0.557936  ],
                [ 0.15481488,  0.49331293,  0.55783967],
                [ 0.15336445,  0.49700003,  0.55772371],
                [ 0.1519182 ,  0.50068529,  0.55758733],
                [ 0.15047605,  0.50436904,  0.55742968],
                [ 0.14903918,  0.50805136,  0.5572505 ],
                [ 0.14760731,  0.51173263,  0.55704861],
                [ 0.14618026,  0.51541316,  0.55682271],
                [ 0.14475863,  0.51909319,  0.55657181],
                [ 0.14334327,  0.52277292,  0.55629491],
                [ 0.14193527,  0.52645254,  0.55599097],
                [ 0.14053599,  0.53013219,  0.55565893],
                [ 0.13914708,  0.53381201,  0.55529773],
                [ 0.13777048,  0.53749213,  0.55490625],
                [ 0.1364085 ,  0.54117264,  0.55448339],
                [ 0.13506561,  0.54485335,  0.55402906],
                [ 0.13374299,  0.54853458,  0.55354108],
                [ 0.13244401,  0.55221637,  0.55301828],
                [ 0.13117249,  0.55589872,  0.55245948],
                [ 0.1299327 ,  0.55958162,  0.55186354],
                [ 0.12872938,  0.56326503,  0.55122927],
                [ 0.12756771,  0.56694891,  0.55055551],
                [ 0.12645338,  0.57063316,  0.5498411 ],
                [ 0.12539383,  0.57431754,  0.54908564],
                [ 0.12439474,  0.57800205,  0.5482874 ],
                [ 0.12346281,  0.58168661,  0.54744498],
                [ 0.12260562,  0.58537105,  0.54655722],
                [ 0.12183122,  0.58905521,  0.54562298],
                [ 0.12114807,  0.59273889,  0.54464114],
                [ 0.12056501,  0.59642187,  0.54361058],
                [ 0.12009154,  0.60010387,  0.54253043],
                [ 0.11973756,  0.60378459,  0.54139999],
                [ 0.11951163,  0.60746388,  0.54021751],
                [ 0.11942341,  0.61114146,  0.53898192],
                [ 0.11948255,  0.61481702,  0.53769219],
                [ 0.11969858,  0.61849025,  0.53634733],
                [ 0.12008079,  0.62216081,  0.53494633],
                [ 0.12063824,  0.62582833,  0.53348834],
                [ 0.12137972,  0.62949242,  0.53197275],
                [ 0.12231244,  0.63315277,  0.53039808],
                [ 0.12344358,  0.63680899,  0.52876343],
                [ 0.12477953,  0.64046069,  0.52706792],
                [ 0.12632581,  0.64410744,  0.52531069],
                [ 0.12808703,  0.64774881,  0.52349092],
                [ 0.13006688,  0.65138436,  0.52160791],
                [ 0.13226797,  0.65501363,  0.51966086],
                [ 0.13469183,  0.65863619,  0.5176488 ],
                [ 0.13733921,  0.66225157,  0.51557101],
                [ 0.14020991,  0.66585927,  0.5134268 ],
                [ 0.14330291,  0.66945881,  0.51121549],
                [ 0.1466164 ,  0.67304968,  0.50893644],
                [ 0.15014782,  0.67663139,  0.5065889 ],
                [ 0.15389405,  0.68020343,  0.50417217],
                [ 0.15785146,  0.68376525,  0.50168574],
                [ 0.16201598,  0.68731632,  0.49912906],
                [ 0.1663832 ,  0.69085611,  0.49650163],
                [ 0.1709484 ,  0.69438405,  0.49380294],
                [ 0.17570671,  0.6978996 ,  0.49103252],
                [ 0.18065314,  0.70140222,  0.48818938],
                [ 0.18578266,  0.70489133,  0.48527326],
                [ 0.19109018,  0.70836635,  0.48228395],
                [ 0.19657063,  0.71182668,  0.47922108],
                [ 0.20221902,  0.71527175,  0.47608431],
                [ 0.20803045,  0.71870095,  0.4728733 ],
                [ 0.21400015,  0.72211371,  0.46958774],
                [ 0.22012381,  0.72550945,  0.46622638],
                [ 0.2263969 ,  0.72888753,  0.46278934],
                [ 0.23281498,  0.73224735,  0.45927675],
                [ 0.2393739 ,  0.73558828,  0.45568838],
                [ 0.24606968,  0.73890972,  0.45202405],
                [ 0.25289851,  0.74221104,  0.44828355],
                [ 0.25985676,  0.74549162,  0.44446673],
                [ 0.26694127,  0.74875084,  0.44057284],
                [ 0.27414922,  0.75198807,  0.4366009 ],
                [ 0.28147681,  0.75520266,  0.43255207],
                [ 0.28892102,  0.75839399,  0.42842626],
                [ 0.29647899,  0.76156142,  0.42422341],
                [ 0.30414796,  0.76470433,  0.41994346],
                [ 0.31192534,  0.76782207,  0.41558638],
                [ 0.3198086 ,  0.77091403,  0.41115215],
                [ 0.3277958 ,  0.77397953,  0.40664011],
                [ 0.33588539,  0.7770179 ,  0.40204917],
                [ 0.34407411,  0.78002855,  0.39738103],
                [ 0.35235985,  0.78301086,  0.39263579],
                [ 0.36074053,  0.78596419,  0.38781353],
                [ 0.3692142 ,  0.78888793,  0.38291438],
                [ 0.37777892,  0.79178146,  0.3779385 ],
                [ 0.38643282,  0.79464415,  0.37288606],
                [ 0.39517408,  0.79747541,  0.36775726],
                [ 0.40400101,  0.80027461,  0.36255223],
                [ 0.4129135 ,  0.80304099,  0.35726893],
                [ 0.42190813,  0.80577412,  0.35191009],
                [ 0.43098317,  0.80847343,  0.34647607],
                [ 0.44013691,  0.81113836,  0.3409673 ],
                [ 0.44936763,  0.81376835,  0.33538426],
                [ 0.45867362,  0.81636288,  0.32972749],
                [ 0.46805314,  0.81892143,  0.32399761],
                [ 0.47750446,  0.82144351,  0.31819529],
                [ 0.4870258 ,  0.82392862,  0.31232133],
                [ 0.49661536,  0.82637633,  0.30637661],
                [ 0.5062713 ,  0.82878621,  0.30036211],
                [ 0.51599182,  0.83115784,  0.29427888],
                [ 0.52577622,  0.83349064,  0.2881265 ],
                [ 0.5356211 ,  0.83578452,  0.28190832],
                [ 0.5455244 ,  0.83803918,  0.27562602],
                [ 0.55548397,  0.84025437,  0.26928147],
                [ 0.5654976 ,  0.8424299 ,  0.26287683],
                [ 0.57556297,  0.84456561,  0.25641457],
                [ 0.58567772,  0.84666139,  0.24989748],
                [ 0.59583934,  0.84871722,  0.24332878],
                [ 0.60604528,  0.8507331 ,  0.23671214],
                [ 0.61629283,  0.85270912,  0.23005179],
                [ 0.62657923,  0.85464543,  0.22335258],
                [ 0.63690157,  0.85654226,  0.21662012],
                [ 0.64725685,  0.85839991,  0.20986086],
                [ 0.65764197,  0.86021878,  0.20308229],
                [ 0.66805369,  0.86199932,  0.19629307],
                [ 0.67848868,  0.86374211,  0.18950326],
                [ 0.68894351,  0.86544779,  0.18272455],
                [ 0.69941463,  0.86711711,  0.17597055],
                [ 0.70989842,  0.86875092,  0.16925712],
                [ 0.72039115,  0.87035015,  0.16260273],
                [ 0.73088902,  0.87191584,  0.15602894],
                [ 0.74138803,  0.87344918,  0.14956101],
                [ 0.75188414,  0.87495143,  0.14322828],
                [ 0.76237342,  0.87642392,  0.13706449],
                [ 0.77285183,  0.87786808,  0.13110864],
                [ 0.78331535,  0.87928545,  0.12540538],
                [ 0.79375994,  0.88067763,  0.12000532],
                [ 0.80418159,  0.88204632,  0.11496505],
                [ 0.81457634,  0.88339329,  0.11034678],
                [ 0.82494028,  0.88472036,  0.10621724],
                [ 0.83526959,  0.88602943,  0.1026459 ],
                [ 0.84556056,  0.88732243,  0.09970219],
                [ 0.8558096 ,  0.88860134,  0.09745186],
                [ 0.86601325,  0.88986815,  0.09595277],
                [ 0.87616824,  0.89112487,  0.09525046],
                [ 0.88627146,  0.89237353,  0.09537439],
                [ 0.89632002,  0.89361614,  0.09633538],
                [ 0.90631121,  0.89485467,  0.09812496],
                [ 0.91624212,  0.89609127,  0.1007168 ],
                [ 0.92610579,  0.89732977,  0.10407067],
                [ 0.93590444,  0.8985704 ,  0.10813094],
                [ 0.94563626,  0.899815  ,  0.11283773],
                [ 0.95529972,  0.90106534,  0.11812832],
                [ 0.96489353,  0.90232311,  0.12394051],
                [ 0.97441665,  0.90358991,  0.13021494],
                [ 0.98386829,  0.90486726,  0.13689671],
                [ 0.99324789,  0.90615657,  0.1439362 ]];
            if nargin < 1
                cm_data = cm;
            else
                hsv=rgb2hsv(cm);
                cm_data=interp1(linspace(0,1,size(cm,1)),hsv,linspace(0,1,m));
                cm_data=hsv2rgb(cm_data);

            end
        end%FCN:ColMapViridis

        function DrawCircle(x,y,r, col, w)
            th = 0:pi/50:2*pi;
            xunit = r * cos(th) + x;
            yunit = r * sin(th) + y;
            plot(xunit, yunit, 'Color', col, 'Linewidth', w);
        end%FCN:DrawCircle

        function objective = evalfun(ground_truth, w, dist_measure, socio_visual, nutri_visual, socio_olfactory, nutri_olfactory)

            % Probability that th option is a good one
            P_good = @(a,b) 1./(1+a.^-b);

            % Turn reliabilities into matrices
            socio_visual = ones(size(w.socio_visual))*socio_visual;
            nutri_visual = ones(size(w.socio_visual))*nutri_visual;
            socio_olfactory = ones(size(w.socio_visual))*socio_olfactory;
            nutri_olfactory = ones(size(w.socio_visual))*nutri_olfactory;

            % Apply for each class
            P_good_socio_visual = P_good(socio_visual, w.socio_visual);
            P_good_nutri_visual = P_good(nutri_visual, w.nutri_visual);
            P_good_socio_olfactory = P_good(socio_olfactory, w.socio_olfactory);
            P_good_nutri_olfactory = P_good(nutri_olfactory, w.nutri_olfactory);

            % Get probability of choosing a quarter
            P = nan(size(w.socio_visual));
            for iStim = 1:size(P,1)
                for iBin = 1:size(P,2)
                    P(iStim, iBin) = P_good_socio_visual(iStim, iBin) * P_good_nutri_visual(iStim, iBin) * P_good_socio_olfactory(iStim, iBin) * P_good_nutri_olfactory(iStim, iBin);
                    P(iStim, iBin) = P(iStim, iBin) /  sum(P_good_socio_visual(iStim, :) .* P_good_nutri_visual(iStim, :) .* P_good_socio_olfactory(iStim, :) .* P_good_nutri_olfactory(iStim, :));
                end%iBin
            end%iStim

            % Get error
            switch dist_measure
                case 'maxRMSE'
                    objective = max(sqrt(mean((ground_truth - P).^2,2)));
                case 'RMSE'
                    objective = sqrt(mean((ground_truth(:) - P(:)).^2,2));
                case 'maxRSS'
                    objective = max(sqrt(sum((ground_truth - P).^2,2)));
                case 'RSS'
                    objective = sqrt(sum((ground_truth(:) - P(:)).^2,2));
                case 'cosine'
                    objective = 1-cos(subspace(ground_truth(:), P(:)));
                case 'correlation'
                    objective = corrcoef(ground_truth(:), P(:));
                    objective = 1-objective(2).^2;
            end% switch
            objective = log1p(objective);

        end%FCN:evalfun

        function [P, dist] = exefun(ground_truth, w, dist_measure, socio_visual, nutri_visual, socio_olfactory, nutri_olfactory)

            % Probability that th option is a good one
            P_good = @(a,b) 1./(1+a.^-b);

            % Turn reliabilities into matrices
            socio_visual = ones(size(w.socio_visual))*socio_visual;
            nutri_visual = ones(size(w.socio_visual))*nutri_visual;
            socio_olfactory = ones(size(w.socio_visual))*socio_olfactory;
            nutri_olfactory = ones(size(w.socio_visual))*nutri_olfactory;

            % Apply for each class
            P_good_socio_visual = P_good(socio_visual, w.socio_visual);
            P_good_nutri_visual = P_good(nutri_visual, w.nutri_visual);
            P_good_socio_olfactory = P_good(socio_olfactory, w.socio_olfactory);
            P_good_nutri_olfactory = P_good(nutri_olfactory, w.nutri_olfactory);

            % Get probability of choosing a quarter
            P = ones(size(w.socio_visual));
            for iStim = 1:size(P,1)
                for iBin = 1:size(P,2)
                    P(iStim, iBin) = P_good_socio_visual(iStim, iBin) * P_good_nutri_visual(iStim, iBin) * P_good_socio_olfactory(iStim, iBin) * P_good_nutri_olfactory(iStim, iBin);
                    P(iStim, iBin) = P(iStim, iBin) /  sum(P_good_socio_visual(iStim, :) .* P_good_nutri_visual(iStim, :) .* P_good_socio_olfactory(iStim, :) .* P_good_nutri_olfactory(iStim, :));
                end%iBin
            end%iStim

            % Get error
            switch dist_measure
                case 'maxRMSE'
                    dist = max(sqrt(mean((ground_truth - P).^2,2)));
                case 'RMSE'
                    dist = sqrt(mean((ground_truth(:) - P(:)).^2,2));
                case 'maxRSS'
                    dist = max(sqrt(sum((ground_truth - P).^2,2)));
                case 'RSS'
                    dist = sqrt(sum((ground_truth(:) - P(:)).^2,2));
                case 'cosine'
                    dist = 1-cos(subspace(ground_truth(:), P(:)));
                case 'correlation'
                    dist = corrcoef(ground_truth(:), P(:));
                    dist = 1-dist(2).^2;
            end% switch

        end%FCN:exefun

    end%methods
end%class



























