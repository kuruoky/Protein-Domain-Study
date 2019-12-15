 function [ match_matrix, C_n, C_e ] = graph_matching( ARG1, ARG2, train )
%   GRADUATED_ASSIGN_ALGORITHM is a function that compute the best match
%   matrix with two ARGs

    % show procedure flag
    sFlag=0;
    
    % set up condition and variable
    % beta is the converging for getting the maximize number
    beta_0 = 0.1;
    beta_f = 20;   % original is 10
    beta_r = 1.025; % original is 1.075
    
    % I control the iteration number for each round
    I_0 = 20;  % original is 4
    I_1 = 200;   % original is 30
    
    % e control a range
    e_B = 0.5;  % original is 0.5
    e_C = 0.05;   % original is 0.05
    
    % e_cov to handle singularity
    e_cov = 0.01;
    
    % node attriubute compatability weight
    alpha = 1; % edge
    delta = 1; % node
    gamma = 0; %linear
    
    % the size of the real matchin matrix
    A=ARG1.num_nodes;
    I=ARG2.num_nodes-1;
    real_size = [A,I];
    
    % adjust ARG1
    M = ARG2.edges_matrix(1:I,1:I,:);
    M_C = ARG2.edges_cov(1:I,1:I,:);
    V = ARG2.nodes_vector(1:I,:);
    
    % the size of the matrix with slacks
    augment_size = real_size+[1,1];
    
    % initial beta to beta_0
    beta = beta_0;
    
    % nil node compatibility percentage
    prct = 105;
    
    % stochastic level
    s_level = 1;
    
    % pre-calculate the node compatability
    C_n=zeros(A+1,I+1);
    
    % create an function handle for calculating compatibility
    % calculate the compatibility
    for a = 1:A
        for i = 1:I
            C_n(a,i) = node_compatibility(ARG1.nodes_vector(a,:),V(i,:));
        end
    end
        
    % calculate nil compatibility
    C_n(A+1, 1:I)=max(0,prctile(C_n(1:A,1:I),min(prct,100),1)*max(prct/100,1));
    C_n(1:A, I+1)=max(0,prctile(C_n(1:A,1:I),min(prct,100),2)*max(prct/100,1));
    C_n(A+1, I+1)=0;
    
    % pre-calculate the edge compatability
    C_e = zeros((A+1)^2,(I+1)^2); 
    
    tmp_edges = NaN(A+1,A+1,size(ARG1.edges_matrix,3));
    tmp_edges(1:A,1:A,:) = ARG1.edges_matrix;
    tmp_edges(A+1,A+1,:) = Inf;
    edge_atr_1 = reshape(tmp_edges,(A+1)^2,[]);
    
    tmp_edges = NaN(I+1,I+1,size(M,3));
    tmp_edges(1:I,1:I,:) = M;
    tmp_edges(I+1,I+1,:) = Inf;
    edge_atr_2 = reshape(tmp_edges,(I+1)^2,[]);
    
    tmp_edges_cov = ones(I+1,I+1,size(M_C,3));
    tmp_edges_cov(1:I,1:I,:) = M_C;
    tmp_edges_cov(I+1,1:I,:) = mean(M_C);
    tmp_edges_cov(1:I,I+1,:) = mean(M_C,2);
    tmp_edges_cov(I+1,I+1,:) = mean(M_C(:));
    edges_cov = reshape(tmp_edges_cov,(I+1)^2,[]);

    for i = 1:(A+1)^2
        for j = 1:(I+1)^2
            C_e(i,j) = edge_compatibility(edge_atr_1(i,:),edge_atr_2(j,:),edges_cov(j,:));
        end
    end
    
    nan_idx = isnan(C_e);
    inf_idx = isinf(C_e);

    % nil<->a
    C_e(nan_idx) = 0;
    % nil<->nil
    tmp = C_e(0~=C_e);
    tmp = tmp(Inf~=tmp);
    C_e(inf_idx) = prctile(tmp(:),min(prct,100))*max(prct/100,1);
    
    % set up the matrix
    m_Head = rand(augment_size);
    m_Head(A+1, I+1)=0;
    
    if sFlag
        figure()
    end
    % start matching  
    while beta<beta_f   % do A until beta is less than beta_f
        
        converge_B = 0; % a flag for terminating process B
        I_B = 0;    % counting the iteration of B

        while ~converge_B && I_B <= I_0 % do B until B is converge or iteration exceeds
            
            m_Head = m_Head + s_level*(2*rand(size(m_Head))-1)*(1/A);
            
            old_B=m_Head;   % get the old matrix
            I_B = I_B+1;    % increment the iteration counting
            
            
            % Build the partial derivative matrix Q
            m_Head_aug = repmat(m_Head,A+1,I+1);
            Q_aug = C_e.*m_Head_aug;
            Q = squeeze(sum(sum(reshape(Q_aug,A+1,A+1,I+1,I+1),1),3));
            
            %add node attribute
            Q=alpha*Q+delta*C_n;
            
            % add linear encouragement
            linear_score = zeros(size(Q));
            non_null = m_Head(1:end-1,1:end-1);
            non_null_linear = non_null(3:end,3:end).*non_null(1:end-2,1:end-2);
            linear_score(2:end-2,2:end-2)=non_null_linear;
            null_v = m_Head(:,end);
            null_v_linear = null_v(3:end).*null_v(1:end-2);
            null_h = m_Head(end,:);
            null_h_linear = null_h(3:end).*null_h(1:end-2);
            linear_score(2:end-1,end)=null_v_linear;
            linear_score(end,2:end-1)=null_h_linear;
            Q=Q+gamma*linear_score;
            
            % Now update m_Head!
            m_Head=exp(beta*Q);
            m_Head(A+1, I+1)=0;

            % Setup converge in C step
            converge_C = 0; % a flag for terminating process B
            I_C = 0;    % counting the iteration of C
            
            while ~converge_C && I_C <= I_1    % Begin C
                I_C=I_C+1;  % increment C
                old_C=m_Head;   % get the m_Head before processing to determine convergence
                
                normalized_match()
                
                % check convergence
                convergeC();
            end
                        
            % check convergence
            if sFlag
                subplot(1,2,1)
                imshow(m_Head,'InitialMagnification',1000);       
                drawnow;
                subplot(1,2,2)
                imshow(C_n/10,'InitialMagnification',1000); 
                drawnow;
            end
            convergeB();
        end
        
        % increment beta
        beta=beta_r*beta;
    end

    % Set up return
    
    % get the match_matrix in real size
    match_matrix = heuristic(m_Head,A,I,train);
    
    % modify compatibility
    C_n = C_n(1:A,1:I+1);
    for p = A+1:A+1:(A+1)*A
        C_e(p,:)=NaN;      
    end
    C_e((A+1)*A+1:(A+1)*(A+1),:)=NaN;
    C_e = C_e(~any(isnan(C_e),2),:);
    
    % debug purpose
    if sFlag
        close()
    end
    

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % INNER FUNCTION SECTION
    function [] = convergeC()
        converge_C = abs(sum(sum(m_Head-old_C)))<e_C;
    end

    function [] = convergeB()
        converge_B = abs(sum(sum(m_Head(1:A,1:I)-old_B(1:A,1:I))))<e_B;
    end

    function [] = normalized_match()
        m_Head = bsxfun(@rdivide,m_Head,sqrt(sum(m_Head.^2,2)));
        m_Head = m_Head.^2;
        m_Head = bsxfun(@rdivide,m_Head,sqrt(sum(m_Head.^2,1)));
        m_Head = m_Head.^2;
%         m_Head = bsxfun(@rdivide,m_Head,sqrt(sum(m_Head.^2,2))).*bsxfun(@rdivide,m_Head,sqrt(sum(m_Head.^2,1)));
    end 

    function [score] = node_compatibility(atr1, atr2)
        score = atr2(atr1);
    end

    function [score] = edge_compatibility(atr1, atr2, cov)
        
        if ~any(atr1) || ~any(atr2)
            score = 0;
            return
        elseif any(isnan(atr1)) || any(isnan(atr2))
            score = NaN;
            return
        elseif any(isinf(atr1)) || any(isinf(atr2))
            score = Inf;
            return
        end
        
        cov = reshape(cov, length(atr2), length(atr2));
        cov = cov+eye(size(cov))*e_cov;
        score = exp(-0.5*(atr1-atr2)*(cov\(atr1-atr2)'))/(sqrt(det(cov))*(2*pi)^(length(atr2)/2));
    end

    function M = normalize_compatibility(M)
            M = normr(M).*normr(M);
            M = normc(M).*normc(M);
            M = normr(M).*normr(M);
    end

end

