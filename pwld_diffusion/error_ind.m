function err_i = error_ind(z,nel,n_edge,vert,connectivity,edg2poly,edg2vert,c_diff,i_mat)
% error indication

% initialize
err_i=zeros(nel,1);

m1d=[2 1 ; 1 2]/6;

for ied=1:n_edge,
    
    % get K-,K+ and their connectivities
    Kp = edg2poly(ied,2);
    Km = edg2poly(ied,1);
    
    % we want to loop only on INTERIOR edges
    if(Kp<0), continue; end
    
    % get the polygons' connectivities
    gp = connectivity{Kp}(:);
    gm = connectivity{Km}(:);
    % nbr of vertices in each poly
    nvp = length(gp);
    nvm = length(gm);
    % get edge vertices of K+ side
    W = edg2vert(ied,3:4);
    % get edge vertices of K- side
    V = edg2vert(ied,1:2);
    % get the local ID of the edge's first vertex in K+
    indp = find( gp == W(1) );
    if(length(indp) ~= 1),
        error('length(IDp) ~= 1');
    end
    if(indp ~= nvp)
        IDp = [indp (indp+1) ];
    else
        IDp = [indp 1 ];
    end
    % get the local ID of the edge's first vertex in K-
    indm = find( gm == V(1) );
    if(length(indm) ~= 1),
        error('length(IDm) ~= 1');
    end
    if(indm ~= nvm)
        IDm = [indm (indm+1) ];
    else
        IDm = [indm 1 ];
    end
    
    % length current edge
    Le = norm( diff(vert(V,:)) );
    % material properties
    Dp = c_diff(i_mat(Kp));
    Dm = c_diff(i_mat(Km));
    
    % error vector for that edge
    delta_phi = z(gm(IDm)) - flipud(z(gp(IDp)));
    % contribution of that edge to the error in cell iel
%     if(Kp==1||Kp==11||Kp==21||Km==1||Km==11||Km==21)
%         [Km,Kp]
%         delta_phi
%         sum(delta_phi.^2)
% %         delta_phi'*m1d*delta_phi
% %         disp('wwww')
%         pause
%     end
ee=sqrt(Le* (delta_phi'*m1d*delta_phi));
% ee=(delta_phi'*m1d*delta_phi);
% ee=sum(delta_phi.^2);
    err_i(Km) = err_i(Km) + ee;
    err_i(Kp) = err_i(Kp) + ee;
    %     err_i(Km) = err_i(Km) + sqrt(Le* (delta_phi'*m1d*delta_phi));
    %     err_i(Kp) = err_i(Kp) + sqrt(Le* (delta_phi'*m1d*delta_phi));
    
end

%     g=connectivity{iel}(:);
%     xx=vert(g,1); yy=vert(g,2);
%     [or,area_poly] = polyorient(xx,yy);
%     err_i(iel) = err_i(iel) / area_poly;

end
