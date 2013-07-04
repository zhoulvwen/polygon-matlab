function rectangular_pwld()

close all; clc;clear A; clear MM;

% clear all; close all; clc
%
% data
%
tot=1/3;sca=1/3;
Lx=1; c_diff=1/(3*tot); sigma_a=tot-sca; S_ext=10; Ly=Lx;
% bc type: 0= Dirichlet, homogeneous
%          1= Neumann, homogeneous
%          2= Neumann, inhomogeneous
% values entered as LRBT
bc_type=[0 0 0 0];
bc_val.bottom=-10;
%
% numerical parameters
%
nx=3; ny=nx;
x=linspace(0,Lx,nx+1); y=linspace(0,Ly,ny+1);
nel=nx*ny;
i_mat=ones(nel,1);
ndof = 4*nel;
C_pen=4;
C_pen_bd=2*C_pen;
% 4---3   vertex anti-clockwise ordering,
% |   |
% 1---2
connectivity=zeros(nel,4);
for iel=1:nel
    skip = 4*(iel-1);
    i1 = skip + 1;
    i2 = skip + 2;
    i3 = skip + 3;
    i4 = skip + 4;
    connectivity(iel,:)=[i1 i2 i3 i4];
end
% DG vertex coordinates (they are duplicated for simplicity)
ind=0;
vert=zeros(ndof,2);
for iel=1:nel
    j = floor((iel-1)/nx) + 1;
    i = iel - (j-1)*nx;
    %     [iel i j]
    vert(ind+1,1:2)=[x(i)   y(j)  ];
    vert(ind+2,1:2)=[x(i+1) y(j)  ];
    vert(ind+3,1:2)=[x(i+1) y(j+1)];
    vert(ind+4,1:2)=[x(i)   y(j+1)];
    ind = ind + 4;
end
% single coordinates
ind=0;
vert_grid=zeros((nx+1)*(ny+1),2);
for j=1:ny+1
    for i=1:nx+1
        ind=ind+1;
        vert_grid(ind,1:2)=[x(i) y(j)];
    end
end
% find relationship between vert and vert_grid
vert_link=zeros(ndof,1);
for i=1:ndof
    v=vert(i,1:2);
    for k=1:(nx+1)*(ny+1)
        if(norm( vert_grid(k,:)-v )<1e-12)
            if(vert_link(i)~=0), error('vert_link(i) should be 0'); end
            vert_link(i)=k;
        end
    end
end
% edge data
n_edge=0;
edg2poly=zeros(0,2);
edg_normal=zeros(0,2);
edg2vert=zeros(0,4);
for iel=1:nel
    elem=connectivity(iel,:);
    nedg=length(elem);
    elem(end+1)=elem(1);
    for i=1:nedg
        ed=elem(i:i+1);
        [edg2poly,edg2vert,n_edge]=is_edge_already_recorded(...
            ed,edg2poly,edg2vert,iel,vert_link,n_edge);
    end
end
clear vert_link; % not needed any longer
% assign bc markers: LRBT = -( 10 20 30 40 )
for ied=1:n_edge
    % get K+ for that edge
    Kp = edg2poly(ied,2);
    % we want to loop only on BOUNDARY edges
    if(Kp>0), continue; end
    % get the 2 vertices associated with that edge
    P=edg2vert(ied,1:2);
    v=vert(P,:);
    x1=v(1,1); y1=v(1,2);
    x2=v(2,1); y2=v(2,2);
    % assign BC markers
    if(abs(x1)<1e-14 && abs(x2)<1e-14),
        edg2poly(ied,2)=-10; % left
    end
    if(abs(x1-Lx)<1e-14 && abs(x2-Lx)<1e-14),
        edg2poly(ied,2)=-20; % right
    end
    if(abs(y1)<1e-14 && abs(y2)<1e-14),
        edg2poly(ied,2)=-30; % bottom
    end
    if(abs(y1-Ly)<1e-14 && abs(y2-Ly)<1e-14),
        edg2poly(ied,2)=-40; % top
    end
end

% compute edge normals
for ied=1:n_edge
    v1=vert(edg2vert(ied,1),:);
    v2=vert(edg2vert(ied,2),:);
    vec=v2-v1;
    vec=vec/norm(vec);
    edg_normal(ied,1:2)=[vec(2) -vec(1)];
end
% DG assemble volumetric terms
A = spalloc(ndof,ndof,9); b=zeros(ndof,1);
for iel=1:nel
    g=connectivity(iel,:);
    v=vert(g,:);
    mat = i_mat(iel);
    [M,K,f,grad{iel}]=build_pwld_local_matrices(g,v);
    A(g(:),g(:)) = A(g(:),g(:)) + c_diff(mat)*K +sigma_a(mat)*M;
    b(g(:)) = b(g(:)) + S_ext(mat)*f;
end
qq=load('..\a_vol_epetra.txt');
for k=1:length(qq(:,1))
    i =qq(k,2)+1;
    j =qq(k,3)+1;
    va=qq(k,4);
    aa_vol(i,j)=va;
end


% discrepancy_vol=A-aa_vol;
% figure;
% surf(discrepancy_vol);
% disp('check')

% spy(A)
% DG assemble edge terms
%
%           v2 ^  w1
%              |
%              |  n_ed
%  Minus side  | --->    Plus side
%              |
%              |
%           v1 .  w2
%
m1d=[2 1 ; 1 2]/6;
m1d_mod=[1 2; 2 1]/6;

C_pen=4;KK=1;
warning('C_pen=0 ... must remove after debugging');

for ied=1:n_edge
    % get K-,K+ and their connectivities
    Kp = edg2poly(ied,2);
    Km = edg2poly(ied,1);
    % we want to loop only on INTERIOR edges
    if(Km<=0 || Kp==0), error('Km<=0 or Kp==0'); end
    if(Kp<0), continue; end
    % get the polygons' connectivities
    gp = connectivity(Kp,:);
    gm = connectivity(Km,:);
    % nbr of vertices in each poly
    nvp = length(gp);
    nvm = length(gm);
    % get normal
    ne = edg_normal(ied,1:2);
    % get edge vertices of K+ side
    W = edg2vert(ied,3:4);
    % get edge vertices of K- side
    V = edg2vert(ied,1:2);
    % get the local ID of the edge's first vertex in K+
    indp = find( gp == W(1) );
    if(length(indp) ~= 1), error('length(IDp) ~= 1'); end
    if(indp ~= nvp)
        IDp = [indp (indp+1) ];
    else
        IDp = [indp 1 ];
    end
    % get the local ID of the edge's first vertex in K-
    indm = find( gm == V(1) );
    if(length(indm) ~= 1), error('length(IDm) ~= 1'); end
    if(indm ~= nvm)
        IDm = [indm (indm+1) ];
    else
        IDm = [indm 1 ];
    end
    %     % skipping indices
    %     skip_p = [(indp:nvp) (1:indp-1)];
    %     skip_m = [(indm:nvm) (1:indm-1)];
    %     skip_pr= [(indp:-1:1) (nvp:-1:indp+1)];
    %     skip_mr= [(indm:-1:1) (nvm:-1:indm+1)];

    % length current edge
    Le = norm( diff(vert(V,:)) );
    % material properties
    Dp = c_diff(i_mat(Kp));
    Dm = c_diff(i_mat(Km));
    % penalty term
    h_perp=Le; % temporary!
    pen = C_pen * (Dp/h_perp + Dm/h_perp) /2;

    % build the local edge gradient matrices
    % [[phi]],{{D.grad(b).ne}}
    %      = (phi+ - phi-)(D+ grad(b+).ne + D- grad(b-).ne)/2
    %      =  (phi+) D+ grad(b+).ne/2
    %       + (phi+) D- grad(b-).ne/2
    %       - (phi-) D+ grad(b+).ne/2
    %       - (phi-) D- grad(b-).ne/2
    % [[b]],{{D.grad(phi).ne}}
    %      = (b+ - b-)(D+ grad(phi+).ne + D- grad(phi-).ne)/2
    %      =  (b+) D+ grad(phi+).ne/2
    %       + (b+) D- grad(phi-).ne/2
    %       - (b-) D+ grad(phi+).ne/2
    %       - (b-) D- grad(phi-).ne/2
    % compute row vector: n' * G (ne is already stored as a 1x2 row vector)

    % -/-
    row_grad_m = ne * grad{Km}(:,:,indm);
    % edge matrix for this side
    col_b_m = zeros(nvm,1); col_b_m(IDm) = Le/2;
    aux = -Dm/2 * (col_b_m * row_grad_m + row_grad_m' * col_b_m')*KK;
    aux(IDm,IDm) = aux(IDm,IDm) + pen * Le * m1d;
    A(gm(:),gm(:)) = A(gm(:),gm(:)) + aux;

    % +/+
    row_grad_p = ne * grad{Kp}(:,:,indp);
    % edge matrix for this side
    col_b_p = zeros(nvp,1); col_b_p(IDp) = Le/2;
    aux = +Dp/2 * (col_b_p * row_grad_p + row_grad_p' * col_b_p')*KK;
    aux(IDp,IDp) = aux(IDp,IDp) + pen * Le * m1d;
    A(gp(:),gp(:)) = A(gp(:),gp(:)) + aux;

    % -(test)/+(solution)
    aux = ( -col_b_m * Dp/2*row_grad_p + Dm/2*row_grad_m' * col_b_p')*KK;
    aux(IDm,IDp) = aux(IDm,IDp) - pen * Le * m1d_mod;
    A(gm(:),gp(:)) = A(gm(:),gp(:)) + aux;

    % +(test)/-(solution)
    aux = ( col_b_p * Dm/2*row_grad_m - Dp/2*row_grad_p' * col_b_m')*KK;
    aux(IDp,IDm) = aux(IDp,IDm) - pen * Le * m1d_mod;
    A(gp(:),gm(:)) = A(gp(:),gm(:)) + aux;

end

% qq_mm=load('..\a_vol_mm_epetra.txt');
% qq_pp=load('..\a_vol_pp_epetra.txt');
% qq_pm=load('..\a_vol_pm_epetra.txt');
% qq_mp=load('..\a_vol_mp_epetra.txt');
% qq_pen=load('..\a_vol_pen_epetra.txt');
qq=load('..\a_vol_interior_full_epetra.txt');

% for k=1:length(qq_mm(:,1))
%     i =qq_mm(k,2)+1;
%     j =qq_mm(k,3)+1;
%     va=qq_mm(k,4);
%     aa_vol_intedg_mm(i,j)=va;
% end
% aa_vol_intedg_mm=aa_vol_intedg_mm-aa_vol;
% 
% for k=1:length(qq_pp(:,1))
%     i =qq_pp(k,2)+1;
%     j =qq_pp(k,3)+1;
%     va=qq_pp(k,4);
%     aa_vol_intedg_pp(i,j)=va;
% end
% aa_vol_intedg_pp=aa_vol_intedg_pp-aa_vol;
% 
% for k=1:length(qq_pm(:,1))
%     i =qq_pm(k,2)+1;
%     j =qq_pm(k,3)+1;
%     va=qq_pm(k,4);
%     aa_vol_intedg_pm(i,j)=va;
% end
% aa_vol_intedg_pm=aa_vol_intedg_pm-aa_vol;
% 
% for k=1:length(qq_mp(:,1))
%     i =qq_mp(k,2)+1;
%     j =qq_mp(k,3)+1;
%     va=qq_mp(k,4);
%     aa_vol_intedg_mp(i,j)=va;
% end
% aa_vol_intedg_mp=aa_vol_intedg_mp-aa_vol;
% 
% for k=1:length(qq_pen(:,1))
%     i =qq_pen(k,2)+1;
%     j =qq_pen(k,3)+1;
%     va=qq_pen(k,4);
%     aa_vol_intedg_pen(i,j)=va;
% end
% aa_vol_intedg_pen=aa_vol_intedg_pen-aa_vol;

for k=1:length(qq(:,1))
    i =qq(k,2)+1;
    j =qq(k,3)+1;
    va=qq(k,4);
    aa_vol_intedg(i,j)=va;
end


disp('check')
% figure;
% subplot(2,2,1); surf(MM{1}-aa_vol_intedg_mm);
% subplot(2,2,2); surf(MM{2}-aa_vol_intedg_pp);
% subplot(2,2,3); surf(MM{3}-aa_vol_intedg_pm);
% subplot(2,2,4); surf(MM{4}-aa_vol_intedg_mp);

figure;
surf(A-aa_vol_intedg);

C_pen_bd=4;
warning('C_pen_bd=0 ... must remove after debugging');

% boundary conditions
for ied=1:n_edge
    % get K-,K+ for that edge
    Kp = edg2poly(ied,2);
    Km = edg2poly(ied,1);

    % we want to loop only on BOUNDARY edges
    if(Kp>0), continue; end

    % Neumann on the left:
    if(Kp==-10 && bc_type(1)==1), continue; end
    % Neumann on the right:
    if(Kp==-20 && bc_type(2)==1), continue; end
    % Neumann on the bottom:
    if(Kp==-30 && bc_type(3)==1), continue; end
    % Neumann on the left:
    if(Kp==-40 && bc_type(4)==1), continue; end

    [ied Kp Km]
    % get the polygons' connectivities
    gm = connectivity(Km,:);
    % nbr of vertices in each poly
    nvm = length(gm);
    % get normal
    ne = edg_normal(ied,1:2);
    % get edge vertices of K- side
    V = edg2vert(ied,1:2);
    % get the local ID of the edge's first vertex in K-
    indm = find( gm == V(1) );
    if(length(indm) ~= 1), error('length(IDm) ~= 1'); end
    if(indm ~= nvm)
        IDm = [indm (indm+1) ];
    else
        IDm = [indm 1 ];
    end

    % homogeneous Dirichlet
    if(     (Kp==-10 && bc_type(1)==0) || ...
            (Kp==-20 && bc_type(2)==0) || ...
            (Kp==-30 && bc_type(3)==0) || ...
            (Kp==-40 && bc_type(4)==0) )

        sgn=+1;

        % length current edge
        Le = norm( diff(vert(V,:)) );
        % material properties
        Dm = c_diff(i_mat(Km));
        % penalty term
        h_perp=Le; % temporary!
        pen = C_pen_bd * Dm/h_perp

        row_grad_m = ne * grad{Km}(:,:,indm);
        % edge matrix for this side
        col_b_m = zeros(nvm,1); col_b_m(IDm) = Le/2;
        aux = - sgn * Dm/2 * (col_b_m * row_grad_m + row_grad_m' * col_b_m');
        aux(IDm,IDm) = aux(IDm,IDm) + pen * Le * m1d;
        A(gm(:),gm(:)) = A(gm(:),gm(:)) + aux;
    end

    % inhomogeneous Neumann
    if(     (Kp==-10 && bc_type(1)==2) || ...
            (Kp==-20 && bc_type(2)==2) || ...
            (Kp==-30 && bc_type(3)==2) || ...
            (Kp==-40 && bc_type(4)==2) )

        switch(Kp)
            case{-10}
                val=bc_val.left;
            case{-20}
                val=bc_val.right;
            case{-30}
                val=bc_val.bottom;
            case{-40}
                val=bc_val.top;
            otherwise
                error('inhomogeneous Neumann');
        end
        b(gm(:)) = b(gm(:)) + val*Le/2;

    end

end

% spy(A)

qq=load('..\a_vol_pen_bd_epetra.txt');
qq=load('..\a_vol_edg_bd_epetra.txt');
qq=load('..\a_full_epetra.txt');

for k=1:length(qq(:,1))
    i =qq(k,2)+1;
    j =qq(k,3)+1;
    va=qq(k,4);
    aa_vol_pen_bd(i,j)=va;
end

discrepancy=A-aa_vol_pen_bd;
figure;
surf(discrepancy);
disp('check')


%solve
z=A\b;
[ min(z) max(z)]
% plot
figure(11);clf
for iel=1:nel
    g=connectivity(iel,:);
    patch(vert(g,1),vert(g,2),z(g),z(g),'FaceColor','interp'); %,'LineStyle','none');
end
view(-135,25);
figure(12);clf
% plot on finer mesh
% 4---3   vertex anti-clockwise ordering,
% | c |
% 1---2
for iel=1:nel
    g=connectivity(iel,:);
    v=vert(g,:);
    c=mean(v);
    zc=mean(z(g));
    % alpha coef
    nv=length(g);
    alpha=1/nv;
    for i=1:nv
        i2=i+1; if(i==nv), i2=1; end
        xx=[ vert(g([i i2]),1); c(1)];
        yy=[ vert(g([i i2]),2); c(2)];
        zz=[ z(g([i i2])); zc];
        patch(xx,yy,zz,zz,'LineStyle','none');
    end
end
view(-135,25);

return
end